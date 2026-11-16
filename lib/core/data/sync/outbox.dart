import 'package:sembast/sembast.dart';
import 'package:sembast/timestamp.dart';

import '../local/local_database.dart';
import 'doc_record.dart';

enum OutboxOp {
  set('set'),
  delete('delete');

  const OutboxOp(this.key);
  final String key;

  static OutboxOp fromKey(String key) =>
      values.firstWhere((o) => o.key == key, orElse: () => set);
}

/// Uma escrita local ainda não confirmada pelo Firestore.
final class OutboxEntry {
  const OutboxEntry({
    required this.collection,
    required this.id,
    required this.op,
    required this.queuedAt,
    this.data,
  });

  final String collection;
  final String id;
  final OutboxOp op;
  final DateTime queuedAt;

  /// Campos completos do documento (só para [OutboxOp.set]).
  final DocData? data;

  /// Uma entrada por documento: a operação mais recente substitui a anterior.
  String get key => '$collection/$id';

  @override
  String toString() => 'OutboxEntry(${op.key} $key)';
}

/// Fila persistente de escritas pendentes, gravada no próprio banco local
/// para que uma escrita feita offline sobreviva ao fechamento do app.
///
/// A fila é **compactada por documento**: um `set` seguido de outro `set` no
/// mesmo id guarda só o último; um `delete` descarta o `set` anterior. Assim
/// a fila nunca cresce além do número de documentos tocados offline.
final class Outbox {
  const Outbox(this._local);

  final LocalDatabase _local;

  static const _fieldCollection = 'collection';
  static const _fieldId = 'id';
  static const _fieldOp = 'op';
  static const _fieldData = 'data';
  static const _fieldQueuedAt = 'queuedAt';

  static final _store = stringMapStoreFactory.store('_outbox');

  Future<void> enqueue(DatabaseClient client, OutboxEntry entry) =>
      _store.record(entry.key).put(client, {
        _fieldCollection: entry.collection,
        _fieldId: entry.id,
        _fieldOp: entry.op.key,
        _fieldData: entry.data == null ? null : LocalCodec.encode(entry.data!),
        _fieldQueuedAt: Timestamp.fromDateTime(entry.queuedAt),
      });

  /// Ids de [collection] com escrita pendente.
  Future<Set<String>> pendingIds(
    DatabaseClient client,
    String collection,
  ) async {
    final records = await _store.find(
      client,
      finder: Finder(filter: Filter.equals(_fieldCollection, collection)),
    );
    return {for (final r in records) r.value[_fieldId] as String};
  }

  /// Todas as pendências, da mais antiga para a mais nova.
  Future<List<OutboxEntry>> pending(DatabaseClient client) async {
    final records = await _store.find(
      client,
      finder: Finder(sortOrders: [SortOrder(_fieldQueuedAt)]),
    );
    return records.map((r) => _fromMap(r.value)).toList();
  }

  Future<int> count(DatabaseClient client) => _store.count(client);

  Stream<int> watchCount() => _store.query().onCount(_local.raw);

  /// Remove [entry] da fila, **a menos que** ela tenha sido substituída por
  /// uma operação mais nova no mesmo documento enquanto era enviada.
  Future<void> markSent(OutboxEntry entry) => _local.transaction((txn) async {
        final current = await _store.record(entry.key).get(txn);
        if (current == null) return;
        final queuedAt = current[_fieldQueuedAt] as Timestamp;
        if (queuedAt.toDateTime() == entry.queuedAt) {
          await _store.record(entry.key).delete(txn);
        }
      });

  static OutboxEntry _fromMap(Map<String, Object?> map) {
    final data = map[_fieldData];
    return OutboxEntry(
      collection: map[_fieldCollection] as String,
      id: map[_fieldId] as String,
      op: OutboxOp.fromKey(map[_fieldOp] as String),
      queuedAt: (map[_fieldQueuedAt] as Timestamp).toDateTime(),
      data: data is Map ? LocalCodec.decode(data.cast<String, Object?>()) : null,
    );
  }
}

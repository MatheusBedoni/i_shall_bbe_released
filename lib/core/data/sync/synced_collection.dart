import 'package:sembast/sembast.dart';

import '../local/local_database.dart';
import 'doc_record.dart';
import 'outbox.dart';

/// Uma coleção do banco local cujas escritas são enfileiradas para o
/// Firestore. É a API que os datasources locais usam: ler sempre do banco
/// local; escrever no banco local **e** na [Outbox] na mesma transação, para
/// que nenhuma mudança se perca entre as duas.
final class SyncedCollection {
  SyncedCollection(this._local, this.name, {DateTime Function()? clock})
      : _outbox = Outbox(_local),
        _clock = clock ?? DateTime.now;

  final LocalDatabase _local;
  final Outbox _outbox;
  final DateTime Function() _clock;

  /// Nome da coleção (igual ao do Firestore).
  final String name;

  StoreRef<String, DocData> get _store => _local.store(name);

  static DocRecord _toRecord(RecordSnapshot<String, DocData> snap) =>
      DocRecord(snap.key, LocalCodec.decode(snap.value));

  /// Emite a lista atual e, depois, a cada mudança local (incluindo as que o
  /// motor de sync aplica vindas do Firestore).
  Stream<List<DocRecord>> watch({Finder? finder}) => _store
      .query(finder: finder)
      .onSnapshots(_local.raw)
      .map((snaps) => snaps.map(_toRecord).toList())
      .handleError(LocalErrors.rethrow_);

  /// Emite o documento [id] (ou `null` enquanto não existir) e suas mudanças.
  Stream<DocRecord?> watchDoc(String id) => _store
      .record(id)
      .onSnapshot(_local.raw)
      .map((snap) => snap == null ? null : _toRecord(snap))
      .handleError(LocalErrors.rethrow_);

  Future<List<DocRecord>> find({Finder? finder, DatabaseClient? client}) =>
      LocalErrors.guard(() async {
        final snaps = await _store.find(client ?? _local.raw, finder: finder);
        return snaps.map(_toRecord).toList();
      });

  Future<DocRecord?> get(String id, {DatabaseClient? client}) =>
      LocalErrors.guard(() async {
        final value = await _store.record(id).get(client ?? _local.raw);
        return value == null ? null : DocRecord(id, LocalCodec.decode(value));
      });

  /// Grava o documento inteiro localmente, carimba `updatedAt` e enfileira
  /// o envio. Use [txn] para agrupar várias escritas atomicamente.
  Future<void> put(String id, DocData data, {Transaction? txn}) =>
      _write(txn, (t) async {
        final now = _clock();
        final stamped = {...data, SyncFields.updatedAt: now};
        await _store.record(id).put(t, LocalCodec.encode(stamped));
        await _outbox.enqueue(
          t,
          OutboxEntry(
            collection: name,
            id: id,
            op: OutboxOp.set,
            queuedAt: now,
            data: stamped,
          ),
        );
      });

  /// Apaga localmente e enfileira a exclusão remota.
  Future<void> delete(String id, {Transaction? txn}) => _write(txn, (t) async {
        await _store.record(id).delete(t);
        await _outbox.enqueue(
          t,
          OutboxEntry(
            collection: name,
            id: id,
            op: OutboxOp.delete,
            queuedAt: _clock(),
          ),
        );
      });

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      LocalErrors.guard(() => _local.transaction(action));

  Future<void> _write(
    Transaction? txn,
    Future<void> Function(Transaction txn) action,
  ) =>
      txn != null ? LocalErrors.guard(() => action(txn)) : transaction(action);
}

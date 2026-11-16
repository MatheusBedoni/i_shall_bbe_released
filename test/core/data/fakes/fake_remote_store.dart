import 'dart:async';

import 'package:i_shall_be_released/core/data/sync/doc_record.dart';
import 'package:i_shall_be_released/core/data/sync/remote_store.dart';
import 'package:i_shall_be_released/core/error/exceptions.dart';

/// Firestore em memória: guarda documentos por coleção e emite a coleção
/// inteira a cada mudança, como `snapshots()` faz.
class FakeRemoteStore implements RemoteStore {
  final docs = <String, Map<String, DocData>>{};
  final _controllers = <String, StreamController<List<DocRecord>>>{};

  /// Quando `true`, escritas falham com [NetworkException].
  bool offline = false;

  /// Quando `true`, escritas nunca completam (simula o SDK esperando rede).
  bool hang = false;

  /// Erro lançado nas escritas, se definido (tem prioridade sobre [offline]).
  Object? writeError;

  final writes = <String>[];

  List<DocRecord> snapshot(String collection) => [
        for (final e in (docs[collection] ?? const {}).entries)
          DocRecord(e.key, Map.of(e.value)),
      ];

  /// Simula uma mudança feita por outro dispositivo.
  void remoteSet(String collection, String id, DocData data) {
    docs.putIfAbsent(collection, () => {})[id] = data;
    _emit(collection);
  }

  void remoteDelete(String collection, String id) {
    docs[collection]?.remove(id);
    _emit(collection);
  }

  /// Simula um erro vindo do listener da coleção.
  void failCollection(String collection, Object error) {
    _controllers[collection]?.addError(error);
  }

  void _emit(String collection) {
    final c = _controllers[collection];
    if (c != null && !c.isClosed) c.add(snapshot(collection));
  }

  @override
  Stream<List<DocRecord>> watchCollection(String collection) {
    final controller = _controllers.putIfAbsent(
      collection,
      () => StreamController<List<DocRecord>>.broadcast(),
    );
    return Stream.multi((listener) {
      listener.add(snapshot(collection));
      final sub = controller.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = sub.cancel;
    });
  }

  Future<void> _write(String what) async {
    writes.add(what);
    final error = writeError;
    if (error != null) throw error;
    if (hang) return Completer<void>().future;
    if (offline) throw const NetworkException();
  }

  @override
  Future<void> setDoc(String collection, String id, DocData data) async {
    await _write('set $collection/$id');
    docs.putIfAbsent(collection, () => {})[id] = Map.of(data);
    _emit(collection);
  }

  @override
  Future<void> deleteDoc(String collection, String id) async {
    await _write('delete $collection/$id');
    docs[collection]?.remove(id);
    _emit(collection);
  }

  Future<void> dispose() async {
    for (final c in _controllers.values) {
      await c.close();
    }
  }
}

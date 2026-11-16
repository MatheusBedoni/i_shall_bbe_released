import 'dart:async';

import 'package:sembast/sembast.dart';

import '../../error/exceptions.dart';
import '../local/local_database.dart';
import 'doc_record.dart';
import 'outbox.dart';
import 'remote_store.dart';
import 'sync_status.dart';

/// Mantém o banco local e o Firestore espelhados para um usuário.
///
/// **Leitura (pull)**: ouve cada coleção remota e reconcilia o store local a
/// cada snapshot: documentos novos/alterados são gravados, documentos que
/// sumiram do remoto são apagados. Um documento com escrita local pendente
/// na [Outbox] nunca é sobrescrito pelo remoto (a versão local vence até ser
/// enviada; o eco do Firestore chega depois com o mesmo conteúdo).
///
/// **Escrita (push)**: drena a [Outbox] em ordem, uma operação por vez. Sem
/// rede o envio expira ([pushTimeout]) e o motor entra em [SyncState.offline],
/// tentando de novo com backoff exponencial e imediatamente quando o
/// Firestore volta a responder.
///
/// Conflitos entre dispositivos são resolvidos por `updatedAt`
/// (last-write-wins por documento).
final class SyncEngine {
  SyncEngine({
    required LocalDatabase local,
    required this._remote,
    required this._collections,
    this._pushTimeout = const Duration(seconds: 20),
    Duration Function(int attempt)? retryDelay,
    DateTime Function()? clock,
  })  : _local = local,
        _outbox = Outbox(local),
        _retryDelay = retryDelay ?? defaultRetryDelay,
        _clock = clock ?? DateTime.now;

  final LocalDatabase _local;
  final RemoteStore _remote;
  final List<String> _collections;
  final Outbox _outbox;
  final Duration _pushTimeout;
  final Duration Function(int attempt) _retryDelay;
  final DateTime Function() _clock;

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.initial;

  final _remoteSubs = <String, StreamSubscription<List<DocRecord>>>{};
  StreamSubscription<int>? _outboxSub;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _started = false;
  bool _pushing = false;
  bool _pushRequested = false;

  /// 1s, 2s, 4s, ... até 1 minuto.
  static Duration defaultRetryDelay(int attempt) {
    final seconds = 1 << attempt.clamp(0, 6);
    return Duration(seconds: seconds.clamp(1, 60));
  }

  SyncStatus get status => _status;

  /// Emite a cada mudança de estado (não repete o estado atual ao assinar;
  /// use [status] para o valor inicial).
  Stream<SyncStatus> get statusStream => _statusController.stream;

  bool get isRunning => _started;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscribeRemote();
    _outboxSub = _outbox.watchCount().listen((count) {
      _emit(_status.copyWith(pending: count));
      if (count > 0) _push();
    });
  }

  /// Reconecta os listeners que caíram e envia as pendências agora, sem
  /// esperar o backoff.
  Future<void> syncNow() async {
    if (!_started) return;
    _retryTimer?.cancel();
    _attempt = 0;
    _subscribeRemote();
    await _push();
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _retryTimer?.cancel();
    await _outboxSub?.cancel();
    _outboxSub = null;
    for (final sub in _remoteSubs.values) {
      await sub.cancel();
    }
    _remoteSubs.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  // ------------------------------------------------------------------ pull

  void _subscribeRemote() {
    for (final collection in _collections) {
      if (_remoteSubs.containsKey(collection)) continue;
      _remoteSubs[collection] = _remote.watchCollection(collection).listen(
        (docs) => _onRemoteSnapshot(collection, docs),
        onError: (Object e) => _onRemoteError(collection, e),
        onDone: () => _remoteSubs.remove(collection),
      );
    }
  }

  Future<void> _onRemoteSnapshot(String collection, List<DocRecord> docs) async {
    try {
      await _applyRemote(collection, docs);
    } on Object catch (e) {
      _emit(_status.copyWith(state: SyncState.error, message: _describe(e)));
      return;
    }
    // Snapshot recebido = Firestore respondendo. Se havia pendências presas
    // por falta de rede, tenta enviar já.
    if (_status.state == SyncState.offline || _status.state == SyncState.error) {
      _retryTimer?.cancel();
      _attempt = 0;
      _emit(_status.copyWith(state: SyncState.idle, clearMessage: true));
      _push();
    }
  }

  Future<void> _applyRemote(String collection, List<DocRecord> docs) =>
      _local.transaction((txn) async {
        final store = _local.store(collection);
        final pending = await _outbox.pendingIds(txn, collection);
        final remoteIds = {for (final d in docs) d.id};

        final localSnaps = await store.find(txn);
        final local = {
          for (final s in localSnaps)
            s.key: DocRecord(s.key, LocalCodec.decode(s.value)),
        };

        for (final id in local.keys) {
          if (!remoteIds.contains(id) && !pending.contains(id)) {
            await store.record(id).delete(txn);
          }
        }

        for (final doc in docs) {
          if (pending.contains(doc.id)) continue;
          final existing = local[doc.id];
          if (existing != null && !doc.updatedAt.isAfter(existing.updatedAt)) {
            continue;
          }
          await store.record(doc.id).put(txn, LocalCodec.encode(doc.data));
        }
      });

  void _onRemoteError(String collection, Object error) {
    _remoteSubs.remove(collection)?.cancel();
    final offline = error is NetworkException;
    _emit(_status.copyWith(
      state: offline ? SyncState.offline : SyncState.error,
      message: offline ? null : _describe(error),
    ));
    _scheduleRetry();
  }

  // ------------------------------------------------------------------ push

  Future<void> _push() async {
    if (!_started) return;
    if (_pushing) {
      _pushRequested = true;
      return;
    }
    _pushing = true;
    try {
      do {
        _pushRequested = false;
        if (!await _drainOutbox()) return;
      } while (_pushRequested);
      _attempt = 0;
      _emit(_status.copyWith(
        state: SyncState.idle,
        lastSyncedAt: _clock(),
        clearMessage: true,
      ));
    } finally {
      _pushing = false;
    }
  }

  /// Envia as pendências em ordem. Retorna `false` se parou por erro (e já
  /// agendou nova tentativa).
  Future<bool> _drainOutbox() async {
    final entries = await _outbox.pending(_local.raw);
    if (entries.isEmpty) return true;
    _emit(_status.copyWith(state: SyncState.syncing, clearMessage: true));

    for (final entry in entries) {
      if (!_started) return false;
      try {
        await _send(entry).timeout(_pushTimeout);
      } on TimeoutException {
        return _fail(SyncState.offline);
      } on NetworkException {
        return _fail(SyncState.offline);
      } on Object catch (e) {
        return _fail(SyncState.error, _describe(e));
      }
      await _outbox.markSent(entry);
    }
    return true;
  }

  Future<void> _send(OutboxEntry entry) => switch (entry.op) {
        OutboxOp.set => _remote.setDoc(entry.collection, entry.id, entry.data!),
        OutboxOp.delete => _remote.deleteDoc(entry.collection, entry.id),
      };

  bool _fail(SyncState state, [String? message]) {
    _emit(_status.copyWith(
      state: state,
      message: message,
      clearMessage: message == null,
    ));
    _scheduleRetry();
    return false;
  }

  void _scheduleRetry() {
    if (!_started) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay(_attempt++), () {
      _subscribeRemote();
      _push();
    });
  }

  void _emit(SyncStatus next) {
    if (next == _status) return;
    _status = next;
    if (!_statusController.isClosed) _statusController.add(next);
  }

  static String _describe(Object error) => switch (error) {
        AuthException(:final message) => message,
        ServerException(:final message) => message,
        CacheException(:final message) => message,
        NetworkException(:final message) => message,
        _ => 'Falha ao sincronizar.',
      };
}

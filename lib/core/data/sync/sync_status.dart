enum SyncState {
  /// Tudo enviado e ouvindo o Firestore.
  idle,

  /// Enviando pendências.
  syncing,

  /// Sem rede (ou Firestore sem resposta); pendências aguardam.
  offline,

  /// Falha não transitória (ex.: sem permissão). Tenta de novo com backoff.
  error,
}

/// Estado observável do motor de sincronização, para a UI.
final class SyncStatus {
  const SyncStatus({
    this.state = SyncState.idle,
    this.pending = 0,
    this.lastSyncedAt,
    this.message,
  });

  static const initial = SyncStatus();

  final SyncState state;

  /// Escritas locais ainda não confirmadas pelo Firestore.
  final int pending;
  final DateTime? lastSyncedAt;
  final String? message;

  bool get hasPending => pending > 0;

  SyncStatus copyWith({
    SyncState? state,
    int? pending,
    DateTime? lastSyncedAt,
    String? message,
    bool clearMessage = false,
  }) =>
      SyncStatus(
        state: state ?? this.state,
        pending: pending ?? this.pending,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        message: clearMessage ? null : (message ?? this.message),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatus &&
          other.state == state &&
          other.pending == pending &&
          other.lastSyncedAt == lastSyncedAt &&
          other.message == message;

  @override
  int get hashCode => Object.hash(state, pending, lastSyncedAt, message);

  @override
  String toString() => 'SyncStatus($state, pending: $pending, $message)';
}

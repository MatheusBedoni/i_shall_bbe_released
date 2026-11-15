/// Exceções lançadas pela camada **data** (datasources).
///
/// Os repositórios capturam estas exceções e as convertem em [Failure]s,
/// de modo que o domínio nunca precise lidar com `try/catch`.
class ServerException implements Exception {
  const ServerException([this.message = 'Server error']);
  final String message;

  @override
  String toString() => 'ServerException: $message';
}

class CacheException implements Exception {
  const CacheException([this.message = 'Cache error']);
  final String message;

  @override
  String toString() => 'CacheException: $message';
}

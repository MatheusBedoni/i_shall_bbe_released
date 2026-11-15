/// Falhas de domínio.
///
/// Representam erros *esperados* que atravessam as camadas (data -> domain ->
/// presentation) como valores, nunca como exceções. A camada de apresentação
/// decide como exibí-las ao usuário.
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// Erro vindo de uma fonte externa (API, banco, etc.).
final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erro ao comunicar com o servidor.']);
}

/// Erro vindo do armazenamento local (cache, preferências, etc.).
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erro ao acessar os dados locais.']);
}

/// Erro de validação de regra de negócio.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Falha não mapeada. Use com parcimônia.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Ocorreu um erro inesperado.']);
}

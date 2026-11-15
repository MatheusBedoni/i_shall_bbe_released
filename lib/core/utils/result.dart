import '../error/failures.dart';

/// Tipo de retorno padrão dos repositórios e use cases.
///
/// Substitui `Either<Failure, T>` sem depender de pacotes externos. Sendo uma
/// classe `sealed`, o `switch` do Dart garante tratamento exaustivo.
///
/// ```dart
/// final result = await getGreeting(NoParams());
/// switch (result) {
///   case Success(:final value): print(value);
///   case Error(:final failure): print(failure.message);
/// }
/// ```
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isError => this is Error<T>;

  /// Reduz o resultado a um único valor, tratando os dois casos.
  R fold<R>(R Function(Failure failure) onError, R Function(T value) onSuccess) {
    return switch (this) {
      Success(:final value) => onSuccess(value),
      Error(:final failure) => onError(failure),
    };
  }

  /// Transforma o valor de sucesso preservando a falha.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(:final value) => Success(transform(value)),
      Error(:final failure) => Error(failure),
    };
  }

  /// Retorna o valor ou `null` em caso de falha.
  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        Error() => null,
      };

  /// Retorna a falha ou `null` em caso de sucesso.
  Failure? get failureOrNull => switch (this) {
        Success() => null,
        Error(:final failure) => failure,
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

final class Error<T> extends Result<T> {
  const Error(this.failure);
  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Error<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Error($failure)';
}

import '../utils/result.dart';

/// Contrato base de todo use case.
///
/// Um use case representa **uma** ação do negócio e é a única porta de entrada
/// da apresentação para o domínio. Recebe [Params] e devolve um [Result].
abstract interface class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

/// Use case síncrono, para regras que não envolvem I/O.
abstract interface class SyncUseCase<T, Params> {
  Result<T> call(Params params);
}

/// Marcador para use cases que não recebem parâmetros.
final class NoParams {
  const NoParams();

  @override
  bool operator ==(Object other) => other is NoParams;

  @override
  int get hashCode => 0;
}

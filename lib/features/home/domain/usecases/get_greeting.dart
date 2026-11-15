import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/greeting.dart';
import '../repositories/home_repository.dart';

/// Use case: obter a saudação exibida na tela inicial.
final class GetGreeting implements UseCase<Greeting, NoParams> {
  const GetGreeting(this._repository);

  final HomeRepository _repository;

  @override
  Future<Result<Greeting>> call(NoParams params) => _repository.getGreeting();
}

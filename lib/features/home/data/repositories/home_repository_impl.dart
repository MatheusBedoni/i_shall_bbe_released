import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/greeting.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_data_source.dart';

/// Implementação do repositório: orquestra datasources e traduz exceções
/// em [Failure]s. É a fronteira entre infraestrutura e domínio.
final class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl({required HomeRemoteDataSource remoteDataSource})
      : _remote = remoteDataSource;

  final HomeRemoteDataSource _remote;

  @override
  Future<Result<Greeting>> getGreeting() async {
    try {
      final model = await _remote.fetchGreeting();
      return Success(model.toEntity());
    } on ServerException catch (e) {
      return Error(ServerFailure(e.message));
    } on CacheException catch (e) {
      return Error(CacheFailure(e.message));
    } on Object {
      return const Error(UnexpectedFailure());
    }
  }
}

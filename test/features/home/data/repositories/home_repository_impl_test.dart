import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/exceptions.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/core/utils/result.dart';
import 'package:i_shall_be_released/features/home/data/datasources/home_remote_data_source.dart';
import 'package:i_shall_be_released/features/home/data/models/greeting_model.dart';
import 'package:i_shall_be_released/features/home/data/repositories/home_repository_impl.dart';

class _FakeRemote implements HomeRemoteDataSource {
  _FakeRemote({this.model, this.error});
  final GreetingModel? model;
  final Object? error;

  @override
  Future<GreetingModel> fetchGreeting() async {
    if (error != null) throw error!;
    return model!;
  }
}

void main() {
  final model = GreetingModel(message: 'hi', createdAt: DateTime(2026, 1, 1));

  test('converte model em entidade em caso de sucesso', () async {
    final repo = HomeRepositoryImpl(remoteDataSource: _FakeRemote(model: model));
    final result = await repo.getGreeting();
    expect(result, Success(model.toEntity()));
  });

  test('converte ServerException em ServerFailure', () async {
    final repo = HomeRepositoryImpl(
      remoteDataSource: _FakeRemote(error: const ServerException('500')),
    );
    final result = await repo.getGreeting();
    expect(result.failureOrNull, isA<ServerFailure>());
    expect(result.failureOrNull?.message, '500');
  });

  test('converte exceção desconhecida em UnexpectedFailure', () async {
    final repo = HomeRepositoryImpl(
      remoteDataSource: _FakeRemote(error: StateError('x')),
    );
    final result = await repo.getGreeting();
    expect(result.failureOrNull, isA<UnexpectedFailure>());
  });
}

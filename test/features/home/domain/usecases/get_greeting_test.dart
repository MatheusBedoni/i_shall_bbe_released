import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/core/usecase/usecase.dart';
import 'package:i_shall_be_released/core/utils/result.dart';
import 'package:i_shall_be_released/features/home/domain/entities/greeting.dart';
import 'package:i_shall_be_released/features/home/domain/repositories/home_repository.dart';
import 'package:i_shall_be_released/features/home/domain/usecases/get_greeting.dart';

class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this.response);
  final Result<Greeting> response;

  @override
  Future<Result<Greeting>> getGreeting() async => response;
}

void main() {
  final greeting = Greeting(message: 'hi', createdAt: DateTime(2026, 1, 1));

  test('repassa o sucesso do repositório', () async {
    final useCase = GetGreeting(_FakeHomeRepository(Success(greeting)));
    final result = await useCase(const NoParams());
    expect(result, Success(greeting));
  });

  test('repassa a falha do repositório', () async {
    const failure = ServerFailure('down');
    final useCase = GetGreeting(_FakeHomeRepository(const Error(failure)));
    final result = await useCase(const NoParams());
    expect(result, const Error<Greeting>(failure));
  });
}

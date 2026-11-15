import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/core/utils/result.dart';
import 'package:i_shall_be_released/features/home/domain/entities/greeting.dart';
import 'package:i_shall_be_released/features/home/domain/repositories/home_repository.dart';
import 'package:i_shall_be_released/features/home/domain/usecases/get_greeting.dart';
import 'package:i_shall_be_released/features/home/presentation/controllers/home_controller.dart';
import 'package:i_shall_be_released/features/home/presentation/pages/home_page.dart';

class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this.response);
  final Result<Greeting> response;

  @override
  Future<Result<Greeting>> getGreeting() async => response;
}

HomeController _controller(Result<Greeting> response) =>
    HomeController(getGreeting: GetGreeting(_FakeHomeRepository(response)));

void main() {
  testWidgets('exibe a saudação quando carregada', (tester) async {
    final greeting = Greeting(message: 'Olá', createdAt: DateTime(2026, 1, 1));
    await tester.pumpWidget(
      MaterialApp(home: HomePage(controller: _controller(Success(greeting)))),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Olá'), findsOneWidget);
  });

  testWidgets('exibe erro e botão de retry quando falha', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          controller: _controller(const Error(ServerFailure('Falhou'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Falhou'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

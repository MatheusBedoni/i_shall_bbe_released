import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/features/goals/domain/entities/goal.dart';
import 'package:i_shall_be_released/features/goals/domain/usecases/goal_usecases.dart';

import 'fakes/in_memory_goal_repository.dart';

const _valid = Goal(
  id: '',
  name: '  Reserva  ',
  targetAmount: 10000,
  currentAmount: 0,
  monthlyContribution: 500,
  annualRate: 0.1,
  linkedAssetIds: ['a1', 'a2', 'a1'],
);

void main() {
  group('validateGoal', () {
    test('aceita meta válida', () {
      expect(validateGoal(_valid), isNull);
    });

    test('rejeita nome vazio', () {
      expect(validateGoal(_valid.copyWith(name: '  ')), isA<ValidationFailure>());
    });

    test('rejeita valor da meta zero ou inválido', () {
      expect(validateGoal(_valid.copyWith(targetAmount: 0)), isNotNull);
      expect(validateGoal(_valid.copyWith(targetAmount: double.nan)), isNotNull);
    });

    test('rejeita saldo e aporte negativos', () {
      expect(validateGoal(_valid.copyWith(currentAmount: -1)), isNotNull);
      expect(validateGoal(_valid.copyWith(monthlyContribution: -1)), isNotNull);
    });

    test('aceita aporte zero (meta só com rendimento)', () {
      expect(validateGoal(_valid.copyWith(monthlyContribution: 0)), isNull);
    });

    test('rejeita rentabilidade de -100% ou menos', () {
      expect(validateGoal(_valid.copyWith(annualRate: -1)), isNotNull);
      expect(validateGoal(_valid.copyWith(annualRate: -0.5)), isNull);
    });

    test('rejeita id de ativo vazio', () {
      expect(validateGoal(_valid.copyWith(linkedAssetIds: ['a1', ''])), isNotNull);
    });
  });

  test('normalizeGoal apara o nome e remove vínculos duplicados', () {
    final n = normalizeGoal(_valid);
    expect(n.name, 'Reserva');
    expect(n.linkedAssetIds, ['a1', 'a2']);
  });

  group('use cases', () {
    late InMemoryGoalRepository repo;

    setUp(() => repo = InMemoryGoalRepository());

    test('AddGoal valida, normaliza e persiste', () async {
      final r = await AddGoal(repo)(_valid);
      expect(r.isSuccess, isTrue);
      expect(repo.goals.single.name, 'Reserva');
      expect(repo.goals.single.linkedAssetIds, ['a1', 'a2']);
      expect(repo.goals.single.id, isNotEmpty);
    });

    test('AddGoal inválida não chega ao repositório', () async {
      final r = await AddGoal(repo)(_valid.copyWith(targetAmount: 0));
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(repo.goals, isEmpty);
    });

    test('UpdateGoal permite desvincular todos os ativos', () async {
      final saved = (await AddGoal(repo)(_valid)).valueOrNull!;
      final r = await UpdateGoal(repo)(saved.copyWith(linkedAssetIds: const []));
      expect(r.isSuccess, isTrue);
      expect(repo.goals.single.isLinked, isFalse);
    });

    test('DeleteGoal remove', () async {
      final saved = (await AddGoal(repo)(_valid)).valueOrNull!;
      await DeleteGoal(repo)(saved.id);
      expect(repo.goals, isEmpty);
    });
  });
}

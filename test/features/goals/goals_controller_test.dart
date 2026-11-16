import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/features/goals/domain/entities/goal.dart';
import 'package:i_shall_be_released/features/goals/domain/usecases/goal_usecases.dart';
import 'package:i_shall_be_released/features/goals/presentation/controllers/goals_controller.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/position.dart';

import 'fakes/in_memory_goal_repository.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

Position _position(String id, double value) => Position(
      asset: Asset(id: id, ticker: id.toUpperCase(), name: id, assetClass: AssetClass.stock),
      quantity: 1,
      averagePrice: value,
      realizedPnl: 0,
      dividendsReceived: 0,
    );

const _goal = Goal(
  id: '',
  name: ' Reserva ',
  targetAmount: 10000,
  currentAmount: 1000,
  monthlyContribution: 500,
  annualRate: 0,
  linkedAssetIds: ['a1'],
);

void main() {
  late InMemoryGoalRepository repo;
  late GoalsController c;
  final now = DateTime(2026, 1, 1);

  setUp(() {
    repo = InMemoryGoalRepository();
    c = GoalsController(
      watchGoals: WatchGoals(repo),
      addGoal: AddGoal(repo),
      updateGoal: UpdateGoal(repo),
      deleteGoal: DeleteGoal(repo),
      computeSnapshots: const ComputeGoalSnapshots(),
      clock: () => now,
    );
    c.start();
  });

  tearDown(() => c.dispose());

  test('carrega lista vazia', () async {
    expect(c.loading, isTrue);
    await _flush();
    expect(c.loading, isFalse);
    expect(c.goals, isEmpty);
    expect(c.snapshots(const []), isEmpty);
  });

  test('criar meta normaliza e emite mensagem', () async {
    await _flush();
    final ok = await c.createGoal(_goal);
    await _flush();
    expect(ok, isTrue);
    expect(c.goals.single.name, 'Reserva');
    expect(c.consumeMessage(), contains('Reserva'));
    expect(c.consumeMessage(), isNull);
  });

  test('meta inválida expõe erro e não persiste', () async {
    await _flush();
    final ok = await c.createGoal(_goal.copyWith(targetAmount: 0));
    expect(ok, isFalse);
    expect(c.error, 'O valor da meta deve ser maior que zero.');
    expect(repo.goals, isEmpty);
  });

  test('snapshots somam as posições vinculadas e usam cache', () async {
    await _flush();
    await c.createGoal(_goal);
    await _flush();

    final positions = [_position('a1', 4000), _position('a2', 99)];
    final first = c.snapshots(positions);
    expect(first.single.savedAmount, 5000);
    expect(first.single.linkedPositions.single.asset.id, 'a1');
    // 5000 + 10 × 500 = 10000.
    expect(first.single.projection!.monthsToTarget, 10);

    expect(identical(c.snapshots(positions), first), isTrue,
        reason: 'mesmas metas e posições: não recalcula');

    final other = [_position('a1', 9000)];
    final second = c.snapshots(other);
    expect(identical(second, first), isFalse);
    expect(second.single.savedAmount, 10000);
    expect(second.single.isReached, isTrue);
  });

  test('snapshotOf encontra pela id e some após excluir', () async {
    await _flush();
    await c.createGoal(_goal);
    await _flush();
    final id = c.goals.single.id;
    expect(c.snapshotOf(id, const []), isNotNull);
    expect(c.goalById(id), isNotNull);

    final ok = await c.removeGoal(id);
    await _flush();
    expect(ok, isTrue);
    expect(c.snapshotOf(id, const []), isNull);
    expect(c.consumeMessage(), 'Meta removida.');
  });

  test('editar meta recalcula os snapshots', () async {
    await _flush();
    await c.createGoal(_goal);
    await _flush();
    final before = c.snapshots(const []);
    expect(before.single.savedAmount, 1000);

    await c.editGoal(c.goals.single.copyWith(currentAmount: 2500));
    await _flush();
    final after = c.snapshots(const []);
    expect(after.single.savedAmount, 2500);
  });
}

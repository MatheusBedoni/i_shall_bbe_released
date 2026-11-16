import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/features/goals/domain/entities/goal.dart';
import 'package:i_shall_be_released/features/goals/domain/usecases/compute_goal_snapshots.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/position.dart';

Position _position(String id, String ticker, {required double value}) =>
    Position(
      asset: Asset(id: id, ticker: ticker, name: ticker, assetClass: AssetClass.stock),
      quantity: 1,
      averagePrice: value,
      realizedPnl: 0,
      dividendsReceived: 0,
    );

void main() {
  const useCase = ComputeGoalSnapshots();
  final now = DateTime(2026, 1, 1);
  final positions = [
    _position('a1', 'PETR4', value: 3000),
    _position('a2', 'HGLG11', value: 2000),
    _position('a3', 'VALE3', value: 9999),
  ];

  Goal goal({
    double current = 0,
    double monthly = 1000,
    List<String> linked = const [],
    DateTime? deadline,
  }) =>
      Goal(
        id: 'g',
        name: 'Reserva',
        targetAmount: 12000,
        currentAmount: current,
        monthlyContribution: monthly,
        annualRate: 0,
        deadline: deadline,
        linkedAssetIds: linked,
      );

  test('meta sem vínculo usa só o saldo manual', () {
    final s = useCase(ComputeGoalSnapshotsParams(
      goals: [goal(current: 500)],
      positions: positions,
      now: now,
    )).valueOrNull!.single;
    expect(s.linkedPositions, isEmpty);
    expect(s.linkedValue, 0);
    expect(s.savedAmount, 500);
    expect(s.projection!.timeline.first, 500);
  });

  test('meta vinculada soma o valor atual dos ativos ao saldo manual', () {
    final s = useCase(ComputeGoalSnapshotsParams(
      goals: [goal(current: 500, linked: ['a2', 'a1'])],
      positions: positions,
      now: now,
    )).valueOrNull!.single;
    expect(s.linkedPositions.map((p) => p.asset.ticker), ['HGLG11', 'PETR4']);
    expect(s.linkedValue, 5000);
    expect(s.savedAmount, 5500);
    expect(s.remaining, 6500);
    expect(s.progress, closeTo(5500 / 12000, 1e-9));
    expect(s.missingAssetIds, isEmpty);
  });

  test('projeção parte do saldo total (manual + carteira)', () {
    final s = useCase(ComputeGoalSnapshotsParams(
      goals: [goal(linked: ['a1', 'a2'], monthly: 1000)],
      positions: positions,
      now: now,
    )).valueOrNull!.single;
    // 5000 + 7 × 1000 = 12000.
    expect(s.projection!.timeline.first, 5000);
    expect(s.projection!.monthsToTarget, 7);
  });

  test('ativo apagado da carteira é ignorado e sinalizado', () {
    final s = useCase(ComputeGoalSnapshotsParams(
      goals: [goal(linked: ['a1', 'apagado'])],
      positions: positions,
      now: now,
    )).valueOrNull!.single;
    expect(s.linkedValue, 3000);
    expect(s.missingAssetIds, ['apagado']);
  });

  test('meta atingida pelos ativos vinculados', () {
    final s = useCase(ComputeGoalSnapshotsParams(
      goals: [goal(linked: ['a3', 'a1'])],
      positions: positions,
      now: now,
    )).valueOrNull!.single;
    expect(s.isReached, isTrue);
    expect(s.remaining, 0);
    expect(s.progress, 1);
    expect(s.projection!.monthsToTarget, 0);
  });

  test('onTrackForDeadline compara aporte planejado com o necessário', () {
    final deadline = DateTime(2027, 1, 1);
    final ok = useCase(ComputeGoalSnapshotsParams(
      goals: [goal(monthly: 1000, deadline: deadline)],
      positions: positions,
      now: now,
    )).valueOrNull!.single;
    expect(ok.onTrackForDeadline, isTrue);

    final behind = useCase(ComputeGoalSnapshotsParams(
      goals: [goal(monthly: 500, deadline: deadline)],
      positions: positions,
      now: now,
    )).valueOrNull!.single;
    expect(behind.onTrackForDeadline, isFalse);

    final noDeadline = useCase(ComputeGoalSnapshotsParams(
      goals: [goal()],
      positions: positions,
      now: now,
    )).valueOrNull!.single;
    expect(noDeadline.onTrackForDeadline, isNull);
  });

  test('mantém a ordem das metas e a entidade original intacta', () {
    final g1 = goal(linked: ['a1']);
    final g2 = goal(current: 10).copyWith(id: 'g2', name: 'Viagem');
    final list = useCase(ComputeGoalSnapshotsParams(
      goals: [g1, g2],
      positions: positions,
      now: now,
    )).valueOrNull!;
    expect(list.map((s) => s.goal.id), ['g', 'g2']);
    expect(list.first.goal, same(g1));
    expect(list.first.goal.currentAmount, 0, reason: 'o manual não é alterado');
  });
}

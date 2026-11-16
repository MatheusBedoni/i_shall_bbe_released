import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../../portfolio/domain/entities/position.dart';
import '../entities/goal.dart';
import '../entities/goal_snapshot.dart';
import 'project_goal.dart';

final class ComputeGoalSnapshotsParams {
  const ComputeGoalSnapshotsParams({
    required this.goals,
    required this.positions,
    required this.now,
  });

  final List<Goal> goals;

  /// Posições atuais da carteira (com cotação, quando houver).
  final List<Position> positions;
  final DateTime now;
}

/// Junta cada meta às posições da carteira que ela vincula e projeta o
/// resultado a partir do saldo total (manual + carteira).
final class ComputeGoalSnapshots
    implements SyncUseCase<List<GoalSnapshot>, ComputeGoalSnapshotsParams> {
  const ComputeGoalSnapshots({this.projectGoal = const ProjectGoal()});

  final ProjectGoal projectGoal;

  @override
  Result<List<GoalSnapshot>> call(ComputeGoalSnapshotsParams params) {
    final byAsset = {for (final p in params.positions) p.asset.id: p};
    final snapshots = <GoalSnapshot>[];
    for (final goal in params.goals) {
      final linked = <Position>[
        for (final id in goal.linkedAssetIds)
          if (byAsset[id] != null) byAsset[id]!,
      ];
      final linkedValue = linked.fold(0.0, (s, p) => s + p.currentValue);
      final effective = goal.copyWith(
        currentAmount: goal.currentAmount + linkedValue,
      );
      final projection =
          projectGoal(ProjectGoalParams(goal: effective, now: params.now));
      snapshots.add(GoalSnapshot(
        goal: goal,
        linkedPositions: linked,
        projection: projection.valueOrNull,
      ));
    }
    return Success(snapshots);
  }
}

import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/goal.dart';
import '../../domain/repositories/goal_repository.dart';
import '../datasources/goal_data_source.dart';

final class GoalRepositoryImpl with RepositoryGuard implements GoalRepository {
  const GoalRepositoryImpl(this._ds);
  final GoalDataSource _ds;

  @override
  Stream<Result<List<Goal>>> watchGoals() => wrapStream(_ds.watchGoals);

  @override
  Future<Result<Goal>> addGoal(Goal goal) => guard(() => _ds.addGoal(goal));

  @override
  Future<Result<void>> updateGoal(Goal goal) =>
      guard(() => _ds.updateGoal(goal));

  @override
  Future<Result<void>> deleteGoal(String goalId) =>
      guard(() => _ds.deleteGoal(goalId));
}

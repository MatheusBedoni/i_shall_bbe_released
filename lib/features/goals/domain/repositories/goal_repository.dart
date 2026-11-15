import '../../../../core/utils/result.dart';
import '../entities/goal.dart';

abstract interface class GoalRepository {
  Stream<Result<List<Goal>>> watchGoals();
  Future<Result<Goal>> addGoal(Goal goal);
  Future<Result<void>> updateGoal(Goal goal);
  Future<Result<void>> deleteGoal(String goalId);
}

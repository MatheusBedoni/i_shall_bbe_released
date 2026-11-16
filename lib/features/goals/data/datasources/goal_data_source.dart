import '../../domain/entities/goal.dart';

/// Fonte de dados das metas. A implementação padrão é local
/// (`LocalGoalDataSource`), sincronizada com o Firestore pelo `SyncEngine`.
abstract interface class GoalDataSource {
  Stream<List<Goal>> watchGoals();
  Future<Goal> addGoal(Goal goal);
  Future<void> updateGoal(Goal goal);
  Future<void> deleteGoal(String goalId);
}

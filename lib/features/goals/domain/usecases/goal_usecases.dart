import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/goal.dart';
import '../repositories/goal_repository.dart';

export 'compute_goal_snapshots.dart';
export 'project_goal.dart';

final class WatchGoals {
  const WatchGoals(this._repo);
  final GoalRepository _repo;
  Stream<Result<List<Goal>>> call() => _repo.watchGoals();
}

final class AddGoal implements UseCase<Goal, Goal> {
  const AddGoal(this._repo);
  final GoalRepository _repo;

  @override
  Future<Result<Goal>> call(Goal goal) async {
    final invalid = validateGoal(goal);
    if (invalid != null) return Error(invalid);
    return _repo.addGoal(normalizeGoal(goal));
  }
}

final class UpdateGoal implements UseCase<void, Goal> {
  const UpdateGoal(this._repo);
  final GoalRepository _repo;

  @override
  Future<Result<void>> call(Goal goal) async {
    final invalid = validateGoal(goal);
    if (invalid != null) return Error(invalid);
    return _repo.updateGoal(normalizeGoal(goal));
  }
}

final class DeleteGoal implements UseCase<void, String> {
  const DeleteGoal(this._repo);
  final GoalRepository _repo;

  @override
  Future<Result<void>> call(String goalId) => _repo.deleteGoal(goalId);
}

// -------------------------------------------------------------- Validação

Failure? validateGoal(Goal goal) {
  if (goal.name.trim().isEmpty) {
    return const ValidationFailure('Dê um nome à meta.');
  }
  if (!_finite(goal.targetAmount) || goal.targetAmount <= 0) {
    return const ValidationFailure('O valor da meta deve ser maior que zero.');
  }
  if (!_finite(goal.currentAmount) || goal.currentAmount < 0) {
    return const ValidationFailure('O saldo atual não pode ser negativo.');
  }
  if (!_finite(goal.monthlyContribution) || goal.monthlyContribution < 0) {
    return const ValidationFailure('O aporte mensal não pode ser negativo.');
  }
  if (!_finite(goal.annualRate) || goal.annualRate <= -1) {
    return const ValidationFailure('Rentabilidade anual inválida.');
  }
  if (goal.linkedAssetIds.any((id) => id.trim().isEmpty)) {
    return const ValidationFailure('Ativo vinculado inválido.');
  }
  return null;
}

/// Apara o nome e remove ativos duplicados mantendo a ordem.
Goal normalizeGoal(Goal goal) {
  final seen = <String>{};
  final ids = [
    for (final id in goal.linkedAssetIds)
      if (seen.add(id)) id,
  ];
  return goal.copyWith(name: goal.name.trim(), linkedAssetIds: ids);
}

bool _finite(double v) => !v.isNaN && !v.isInfinite;

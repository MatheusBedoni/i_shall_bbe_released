import 'dart:async';

import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/core/utils/result.dart';
import 'package:i_shall_be_released/features/goals/domain/entities/goal.dart';
import 'package:i_shall_be_released/features/goals/domain/repositories/goal_repository.dart';

/// Metas em memória que imitam o comportamento reativo do banco local.
class InMemoryGoalRepository implements GoalRepository {
  final goals = <Goal>[];
  final _ctrl = StreamController<Result<List<Goal>>>.broadcast();
  int _seq = 0;

  void _emit() => _ctrl.add(Success(List.of(goals)));

  @override
  Stream<Result<List<Goal>>> watchGoals() {
    scheduleMicrotask(_emit);
    return _ctrl.stream;
  }

  @override
  Future<Result<Goal>> addGoal(Goal goal) async {
    final saved = goal.copyWith(id: 'g${_seq++}');
    goals.add(saved);
    _emit();
    return Success(saved);
  }

  @override
  Future<Result<void>> updateGoal(Goal goal) async {
    final i = goals.indexWhere((g) => g.id == goal.id);
    if (i < 0) return const Error(ServerFailure('não encontrada'));
    goals[i] = goal;
    _emit();
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteGoal(String goalId) async {
    goals.removeWhere((g) => g.id == goalId);
    _emit();
    return const Success(null);
  }
}

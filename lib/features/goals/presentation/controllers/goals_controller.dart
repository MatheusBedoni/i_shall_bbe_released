import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../portfolio/domain/entities/position.dart';
import '../../domain/entities/goal.dart';
import '../../domain/entities/goal_snapshot.dart';
import '../../domain/usecases/goal_usecases.dart';

/// Estado da tela de metas.
///
/// As metas vêm do repositório; o saldo dos ativos vinculados vem das
/// posições que o `PortfolioController` já mantém (com cotações). A tela
/// junta os dois chamando [snapshots] com as posições atuais.
final class GoalsController extends ChangeNotifier {
  GoalsController({
    required this.watchGoals,
    required this.addGoal,
    required this.updateGoal,
    required this.deleteGoal,
    required this.computeSnapshots,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final WatchGoals watchGoals;
  final AddGoal addGoal;
  final UpdateGoal updateGoal;
  final DeleteGoal deleteGoal;
  final ComputeGoalSnapshots computeSnapshots;

  final DateTime Function() _clock;

  List<Goal> _goals = const [];
  bool _loaded = false;
  String? _error;
  String? _message;
  StreamSubscription<Object>? _sub;

  // Cache do último cálculo: só refaz quando metas ou posições mudam.
  List<Goal>? _cachedGoals;
  List<Position>? _cachedPositions;
  List<GoalSnapshot> _cachedSnapshots = const [];

  List<Goal> get goals => _goals;
  bool get loading => !_loaded;
  String? get error => _error;

  String? consumeMessage() {
    final m = _message;
    _message = null;
    return m;
  }

  Goal? goalById(String id) {
    for (final g in _goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Metas resolvidas com o saldo dos ativos vinculados em [positions].
  List<GoalSnapshot> snapshots(List<Position> positions) {
    if (identical(_cachedGoals, _goals) &&
        identical(_cachedPositions, positions)) {
      return _cachedSnapshots;
    }
    final result = computeSnapshots(ComputeGoalSnapshotsParams(
      goals: _goals,
      positions: positions,
      now: _clock(),
    ));
    _cachedGoals = _goals;
    _cachedPositions = positions;
    _cachedSnapshots = result.fold((_) => const [], (list) => list);
    return _cachedSnapshots;
  }

  GoalSnapshot? snapshotOf(String goalId, List<Position> positions) {
    for (final s in snapshots(positions)) {
      if (s.goal.id == goalId) return s;
    }
    return null;
  }

  void start() {
    _sub ??= watchGoals().listen((r) {
      _loaded = true;
      r.fold((f) => _setError(f.message), (goals) {
        _goals = goals;
        _error = null;
        notifyListeners();
      });
    });
  }

  Future<bool> createGoal(Goal goal) => _mutate(
        () => addGoal(goal),
        onSuccess: () => _message = 'Meta "${goal.name.trim()}" criada.',
      );

  Future<bool> editGoal(Goal goal) => _mutate(() => updateGoal(goal));

  Future<bool> removeGoal(String goalId) => _mutate(
        () => deleteGoal(goalId),
        onSuccess: () => _message = 'Meta removida.',
      );

  Future<bool> _mutate(
    Future<dynamic> Function() action, {
    void Function()? onSuccess,
  }) async {
    final result = await action();
    return result.fold<bool>(
      (failure) {
        _setError(failure.message);
        return false;
      },
      (_) {
        onSuccess?.call();
        notifyListeners();
        return true;
      },
    );
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

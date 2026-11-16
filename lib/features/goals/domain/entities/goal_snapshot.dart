import 'dart:math' as math;

import '../../../portfolio/domain/entities/position.dart';
import '../usecases/project_goal.dart';
import 'goal.dart';

/// Meta "resolvida": o saldo real (manual + ativos vinculados da carteira) e
/// a projeção calculada sobre ele. É o que as telas exibem.
final class GoalSnapshot {
  const GoalSnapshot({
    required this.goal,
    required this.linkedPositions,
    required this.projection,
  });

  final Goal goal;

  /// Posições da carteira vinculadas à meta, na ordem de [Goal.linkedAssetIds].
  /// Ativos que não existem mais na carteira ficam de fora (ver [missingAssetIds]).
  final List<Position> linkedPositions;

  /// `null` só se a meta for inválida para projeção (ex.: valor zero).
  final GoalProjection? projection;

  /// Valor de mercado dos ativos vinculados.
  double get linkedValue =>
      linkedPositions.fold(0.0, (s, p) => s + p.currentValue);

  /// Saldo total da meta: manual + carteira.
  double get savedAmount => goal.currentAmount + linkedValue;

  double get remaining => math.max(0, goal.targetAmount - savedAmount);

  double get progress => goal.targetAmount <= 0
      ? 0
      : (savedAmount / goal.targetAmount).clamp(0, 1).toDouble();

  bool get isReached => savedAmount >= goal.targetAmount;

  /// Ids vinculados cujo ativo foi apagado da carteira.
  List<String> get missingAssetIds {
    final found = {for (final p in linkedPositions) p.asset.id};
    return goal.linkedAssetIds.where((id) => !found.contains(id)).toList();
  }

  /// O aporte planejado basta para cumprir o prazo? `null` sem prazo.
  bool? get onTrackForDeadline {
    final required = projection?.requiredMonthlyContribution;
    if (required == null) return null;
    return goal.monthlyContribution + 1e-9 >= required;
  }
}

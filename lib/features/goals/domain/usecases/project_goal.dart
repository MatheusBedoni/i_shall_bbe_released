import 'dart:math' as math;

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/goal.dart';

/// Resultado da projeção de uma meta.
final class GoalProjection {
  const GoalProjection({
    required this.monthsToTarget,
    required this.projectedAtDeadline,
    required this.requiredMonthlyContribution,
    required this.timeline,
  });

  /// Meses até atingir a meta com o aporte atual; `null` se nunca atinge
  /// (dentro do horizonte máximo).
  final int? monthsToTarget;

  /// Valor projetado na data limite; `null` se a meta não tem prazo.
  final double? projectedAtDeadline;

  /// Aporte mensal necessário para atingir a meta no prazo; `null` sem prazo.
  final double? requiredMonthlyContribution;

  /// Saldo projetado mês a mês (índice 0 = hoje), até a meta ou o horizonte.
  final List<double> timeline;

  bool get reachesTarget => monthsToTarget != null;
}

final class ProjectGoalParams {
  const ProjectGoalParams({required this.goal, required this.now});
  final Goal goal;
  final DateTime now;
}

/// Juros compostos com aportes mensais no fim de cada mês.
///
/// FV = PV·(1+i)^n + PMT·((1+i)^n − 1)/i, com i = taxa mensal equivalente.
final class ProjectGoal implements SyncUseCase<GoalProjection, ProjectGoalParams> {
  const ProjectGoal({this.maxMonths = 1200});

  /// Horizonte máximo da simulação (100 anos).
  final int maxMonths;

  @override
  Result<GoalProjection> call(ProjectGoalParams params) {
    final goal = params.goal;
    if (goal.targetAmount <= 0) {
      return const Error(ValidationFailure('A meta deve ser maior que zero.'));
    }
    if (goal.annualRate < -0.99) {
      return const Error(ValidationFailure('Taxa anual inválida.'));
    }

    final i = monthlyRate(goal.annualRate);
    final timeline = <double>[goal.currentAmount];
    int? monthsToTarget = goal.isReached ? 0 : null;

    var balance = goal.currentAmount;
    for (var m = 1; m <= maxMonths && monthsToTarget == null; m++) {
      balance = balance * (1 + i) + goal.monthlyContribution;
      timeline.add(balance);
      if (balance >= goal.targetAmount) monthsToTarget = m;
    }

    double? projectedAtDeadline;
    double? requiredContribution;
    final deadline = goal.deadline;
    if (deadline != null) {
      final n = monthsBetween(params.now, deadline);
      projectedAtDeadline = futureValue(
        presentValue: goal.currentAmount,
        monthlyContribution: goal.monthlyContribution,
        monthlyRate: i,
        months: n,
      );
      requiredContribution = requiredMonthlyContribution(
        presentValue: goal.currentAmount,
        target: goal.targetAmount,
        monthlyRate: i,
        months: n,
      );
    }

    return Success(GoalProjection(
      monthsToTarget: monthsToTarget,
      projectedAtDeadline: projectedAtDeadline,
      requiredMonthlyContribution: requiredContribution,
      timeline: timeline,
    ));
  }

  /// Taxa mensal equivalente a uma taxa anual composta.
  static double monthlyRate(double annualRate) =>
      math.pow(1 + annualRate, 1 / 12) - 1;

  static double futureValue({
    required double presentValue,
    required double monthlyContribution,
    required double monthlyRate,
    required int months,
  }) {
    if (months <= 0) return presentValue;
    final growth = math.pow(1 + monthlyRate, months).toDouble();
    final contributions = monthlyRate == 0
        ? monthlyContribution * months
        : monthlyContribution * (growth - 1) / monthlyRate;
    return presentValue * growth + contributions;
  }

  /// Aporte mensal necessário para que [presentValue] alcance [target] em
  /// [months] meses. Zero se já alcançou; `presentValue` cresce sozinho.
  static double requiredMonthlyContribution({
    required double presentValue,
    required double target,
    required double monthlyRate,
    required int months,
  }) {
    if (months <= 0) return math.max(0, target - presentValue);
    final growth = math.pow(1 + monthlyRate, months).toDouble();
    final gap = target - presentValue * growth;
    if (gap <= 0) return 0;
    return monthlyRate == 0 ? gap / months : gap * monthlyRate / (growth - 1);
  }

  /// Meses inteiros entre duas datas (mínimo zero).
  static int monthsBetween(DateTime from, DateTime to) {
    final months = (to.year - from.year) * 12 + (to.month - from.month);
    return math.max(0, to.day < from.day ? months - 1 : months);
  }
}

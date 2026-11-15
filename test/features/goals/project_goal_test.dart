import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/features/goals/domain/entities/goal.dart';
import 'package:i_shall_be_released/features/goals/domain/usecases/project_goal.dart';

void main() {
  const useCase = ProjectGoal();
  final now = DateTime(2026, 1, 1);

  Goal goal({
    double target = 12000,
    double current = 0,
    double monthly = 1000,
    double rate = 0,
    DateTime? deadline,
  }) =>
      Goal(
        id: 'g',
        name: 'Reserva',
        targetAmount: target,
        currentAmount: current,
        monthlyContribution: monthly,
        annualRate: rate,
        deadline: deadline,
      );

  test('sem juros: meses = meta / aporte', () {
    final p = useCase(ProjectGoalParams(goal: goal(), now: now)).valueOrNull!;
    expect(p.monthsToTarget, 12);
    expect(p.timeline.first, 0);
    expect(p.timeline.last, 12000);
    expect(p.projectedAtDeadline, isNull);
  });

  test('com juros chega antes', () {
    // 50% a.a. (~3,4% a.m.): 1000/mês alcança 12.000 antes de 12 meses.
    final p = useCase(ProjectGoalParams(goal: goal(rate: 0.5), now: now)).valueOrNull!;
    expect(p.monthsToTarget, lessThan(12));
    expect(p.reachesTarget, isTrue);
  });

  test('juros baixos não antecipam o prazo mas aumentam o saldo final', () {
    final p = useCase(ProjectGoalParams(goal: goal(rate: 0.12), now: now)).valueOrNull!;
    expect(p.monthsToTarget, 12);
    expect(p.timeline.last, greaterThan(12000));
  });

  test('meta já atingida retorna zero meses', () {
    final p = useCase(ProjectGoalParams(goal: goal(current: 20000), now: now)).valueOrNull!;
    expect(p.monthsToTarget, 0);
  });

  test('sem aporte e sem juros nunca atinge', () {
    final p = useCase(ProjectGoalParams(goal: goal(monthly: 0), now: now)).valueOrNull!;
    expect(p.reachesTarget, isFalse);
    expect(p.timeline.length, 1201);
  });

  test('prazo: valor projetado e aporte necessário', () {
    final p = useCase(ProjectGoalParams(
      goal: goal(monthly: 500, deadline: DateTime(2027, 1, 1)),
      now: now,
    )).valueOrNull!;
    expect(p.projectedAtDeadline, closeTo(6000, 1e-9));
    expect(p.requiredMonthlyContribution, closeTo(1000, 1e-9));
  });

  test('aporte necessário é zero quando o saldo atual já basta', () {
    final p = useCase(ProjectGoalParams(
      goal: goal(current: 12000, deadline: DateTime(2027, 1, 1)),
      now: now,
    )).valueOrNull!;
    expect(p.requiredMonthlyContribution, 0);
  });

  test('meta inválida', () {
    final r = useCase(ProjectGoalParams(goal: goal(target: 0), now: now));
    expect(r.failureOrNull, isA<ValidationFailure>());
  });

  group('fórmulas', () {
    test('taxa mensal equivalente a 12% a.a. ≈ 0,949%', () {
      expect(ProjectGoal.monthlyRate(0.12), closeTo(0.009489, 1e-6));
    });

    test('futureValue com juros', () {
      // 1000 a 1% ao mês por 12 meses, sem aportes: 1000 * 1.01^12
      final fv = ProjectGoal.futureValue(
        presentValue: 1000,
        monthlyContribution: 0,
        monthlyRate: 0.01,
        months: 12,
      );
      expect(fv, closeTo(1126.825, 1e-3));
    });

    test('requiredMonthlyContribution inverte futureValue', () {
      const pv = 1000.0, i = 0.01, n = 24;
      final pmt = ProjectGoal.requiredMonthlyContribution(
        presentValue: pv,
        target: 10000,
        monthlyRate: i,
        months: n,
      );
      final fv = ProjectGoal.futureValue(
        presentValue: pv,
        monthlyContribution: pmt,
        monthlyRate: i,
        months: n,
      );
      expect(fv, closeTo(10000, 1e-6));
    });

    test('monthsBetween', () {
      expect(ProjectGoal.monthsBetween(DateTime(2026, 1, 15), DateTime(2026, 7, 15)), 6);
      expect(ProjectGoal.monthsBetween(DateTime(2026, 1, 15), DateTime(2026, 7, 10)), 5);
      expect(ProjectGoal.monthsBetween(DateTime(2026, 7, 1), DateTime(2026, 1, 1)), 0);
    });
  });
}

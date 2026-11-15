import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/allocation_rule.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/budget_entry.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/budget_period.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/entry_type.dart';
import 'package:i_shall_be_released/features/budget/domain/usecases/compute_budget_summary.dart';

BudgetEntry _entry(EntryType type, double amount) => BudgetEntry(
      id: '${type.name}-$amount',
      period: const BudgetPeriod(year: 2025, month: 12),
      type: type,
      description: type.label,
      amount: amount,
      createdAt: DateTime(2025, 12, 1),
    );

void main() {
  const period = BudgetPeriod(year: 2025, month: 12);
  const useCase = ComputeBudgetSummary();
  final now = DateTime(2025, 12, 12); // 20 dias restantes

  test('calcula envelopes com a regra padrão (33/33/34)', () {
    final result = useCase(ComputeBudgetSummaryParams(
      period: period,
      entries: [
        _entry(EntryType.income, 6000),
        _entry(EntryType.income, 4000),
        _entry(EntryType.fixedExpense, 2000),
        _entry(EntryType.investment, 1000),
        _entry(EntryType.recurringExpense, 500),
      ],
      rule: AllocationRule.defaultRule,
      now: now,
    ));

    final s = result.valueOrNull!;
    expect(s.income, 10000);
    expect(s.fixedExpenses.budget, closeTo(3300, 1e-9));
    expect(s.fixedExpenses.spent, 2000);
    expect(s.fixedExpenses.remaining, closeTo(1300, 1e-9));
    expect(s.investments.budget, closeTo(3300, 1e-9));
    expect(s.recurringExpenses.budget, closeTo(3400, 1e-9));
    expect(s.recurringExpenses.remaining, closeTo(2900, 1e-9));
    expect(s.finalBalance, 6500);
    expect(s.daysRemaining, 20);
    expect(s.dailyAllowance, closeTo(145, 1e-9));
  });

  test('sem ganhos tudo é zero e envelopes estourados marcam isOverBudget', () {
    final s = useCase(ComputeBudgetSummaryParams(
      period: period,
      entries: [_entry(EntryType.recurringExpense, 100)],
      rule: AllocationRule.defaultRule,
      now: now,
    )).valueOrNull!;

    expect(s.income, 0);
    expect(s.recurringExpenses.isOverBudget, isTrue);
    expect(s.recurringExpenses.usedFraction, 1);
    expect(s.dailyAllowance, 0);
    expect(s.finalBalance, -100);
  });

  test('regra personalizada altera os envelopes', () {
    const rule = AllocationRule(fixedExpensePct: 0.5, investmentPct: 0.2);
    final s = useCase(ComputeBudgetSummaryParams(
      period: period,
      entries: [_entry(EntryType.income, 1000)],
      rule: rule,
      now: now,
    )).valueOrNull!;

    expect(s.fixedExpenses.budget, 500);
    expect(s.investments.budget, 200);
    expect(s.recurringExpenses.budget, closeTo(300, 1e-9));
  });

  test('regra inválida retorna ValidationFailure', () {
    const rule = AllocationRule(fixedExpensePct: 0.7, investmentPct: 0.5);
    final result = useCase(ComputeBudgetSummaryParams(
      period: period,
      entries: const [],
      rule: rule,
      now: now,
    ));
    expect(result.failureOrNull, isA<ValidationFailure>());
  });

  test('mês passado não tem gasto diário', () {
    final s = useCase(ComputeBudgetSummaryParams(
      period: period,
      entries: [_entry(EntryType.income, 1000)],
      rule: AllocationRule.defaultRule,
      now: DateTime(2026, 2, 1),
    )).valueOrNull!;
    expect(s.daysRemaining, 0);
    expect(s.dailyAllowance, 0);
  });
}

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

  BudgetSummaryResult compute(List<BudgetEntry> entries, {AllocationRule? rule, DateTime? at}) =>
      BudgetSummaryResult(useCase(ComputeBudgetSummaryParams(
        period: period,
        entries: entries,
        rule: rule ?? AllocationRule.defaultRule,
        now: at ?? now,
      )));

  test('cascata com a regra padrão: fixas 33% do ganho, invest. 33% do que sobra', () {
    final s = compute([
      _entry(EntryType.income, 10000),
      _entry(EntryType.fixedExpense, 3300), // gastou exatamente o orçamento
      _entry(EntryType.investment, 1000),
      _entry(EntryType.recurringExpense, 500),
    ]).value;

    expect(s.income, 10000);
    expect(s.fixedExpenses.budget, closeTo(3300, 1e-9));
    expect(s.fixedExpenses.remaining, closeTo(0, 1e-9));
    // após fixas = 6700 → investimentos = 6700 × 0,33
    expect(s.investments.budget, closeTo(2211, 1e-9));
    // recorrentes = 6700 − 1000 investidos
    expect(s.recurringExpenses.budget, closeTo(5700, 1e-9));
    expect(s.recurringExpenses.remaining, closeTo(5200, 1e-9));
    expect(s.finalBalance, 5200);
    expect(s.daysRemaining, 20);
    expect(s.dailyAllowance, closeTo(260, 1e-9));
  });

  test('fixas menores que o orçamento aumentam investimentos e recorrentes', () {
    final s = compute([
      _entry(EntryType.income, 10000),
      _entry(EntryType.fixedExpense, 2000), // 1300 abaixo do orçamento
      _entry(EntryType.investment, 1000),
    ]).value;

    // após fixas = 8000
    expect(s.investments.budget, closeTo(2640, 1e-9));
    expect(s.recurringExpenses.budget, closeTo(7000, 1e-9));
  });

  test('investimentos menores que o orçamento sobram para recorrentes', () {
    final base = [
      _entry(EntryType.income, 10000),
      _entry(EntryType.fixedExpense, 3300),
    ];
    final semInvestir = compute(base).value;
    final investindoTudo = compute([...base, _entry(EntryType.investment, 2211)]).value;

    expect(semInvestir.recurringExpenses.budget, closeTo(6700, 1e-9));
    expect(investindoTudo.recurringExpenses.budget, closeTo(4489, 1e-9));
  });

  test('fixas acima do orçamento reduzem o que desce na cascata', () {
    final s = compute([
      _entry(EntryType.income, 1000),
      _entry(EntryType.fixedExpense, 900),
    ]).value;

    expect(s.fixedExpenses.isOverBudget, isTrue);
    expect(s.investments.budget, closeTo(33, 1e-9));
    expect(s.recurringExpenses.budget, closeTo(100, 1e-9));
  });

  test('gastos acima do ganho não geram orçamento negativo; saldo final mostra o déficit', () {
    final s = compute([
      _entry(EntryType.income, 1000),
      _entry(EntryType.fixedExpense, 1200),
      _entry(EntryType.recurringExpense, 100),
    ]).value;

    expect(s.investments.budget, 0);
    expect(s.recurringExpenses.budget, 0);
    expect(s.recurringExpenses.isOverBudget, isTrue);
    expect(s.dailyAllowance, 0);
    expect(s.finalBalance, -300);
  });

  test('sem ganhos tudo é zero', () {
    final s = compute([_entry(EntryType.recurringExpense, 100)]).value;
    expect(s.income, 0);
    expect(s.recurringExpenses.usedFraction, 1);
    expect(s.finalBalance, -100);
  });

  test('regra personalizada altera a cascata', () {
    const rule = AllocationRule(fixedExpensePct: 0.5, investmentPct: 0.2);
    final s = compute([
      _entry(EntryType.income, 1000),
      _entry(EntryType.fixedExpense, 500),
    ], rule: rule).value;

    expect(s.fixedExpenses.budget, 500);
    expect(s.investments.budget, closeTo(100, 1e-9)); // 500 × 0,2
    expect(s.recurringExpenses.budget, closeTo(500, 1e-9));
  });

  test('regra inválida retorna ValidationFailure', () {
    const rule = AllocationRule(fixedExpensePct: 1.2, investmentPct: 0.5);
    expect(compute(const [], rule: rule).failure, isA<ValidationFailure>());
  });

  test('percentuais nominais para exibição', () {
    expect(AllocationRule.defaultRule.nominalInvestmentPct, closeTo(0.2211, 1e-9));
    expect(AllocationRule.defaultRule.nominalRecurringPct, closeTo(0.4489, 1e-9));
  });

  test('mês passado não tem gasto diário', () {
    final s = compute([_entry(EntryType.income, 1000)], at: DateTime(2026, 2, 1)).value;
    expect(s.daysRemaining, 0);
    expect(s.dailyAllowance, 0);
  });
}

/// Açúcar para os testes.
final class BudgetSummaryResult {
  BudgetSummaryResult(this._r);
  final dynamic _r;
  dynamic get value => _r.valueOrNull!;
  dynamic get failure => _r.failureOrNull;
}

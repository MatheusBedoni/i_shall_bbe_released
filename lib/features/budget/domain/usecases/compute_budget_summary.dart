import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/allocation_rule.dart';
import '../entities/budget_entry.dart';
import '../entities/budget_period.dart';
import '../entities/budget_summary.dart';
import '../entities/entry_type.dart';

final class ComputeBudgetSummaryParams {
  const ComputeBudgetSummaryParams({
    required this.period,
    required this.entries,
    required this.rule,
    required this.now,
  });

  final BudgetPeriod period;
  final List<BudgetEntry> entries;
  final AllocationRule rule;
  final DateTime now;
}

/// Regra de negócio central do orçamento: a partir dos lançamentos e da regra
/// de alocação, calcula envelopes, saldo e gasto diário permitido.
final class ComputeBudgetSummary
    implements SyncUseCase<BudgetSummary, ComputeBudgetSummaryParams> {
  const ComputeBudgetSummary();

  @override
  Result<BudgetSummary> call(ComputeBudgetSummaryParams params) {
    final invalid = params.rule.validate();
    if (invalid != null) return Error(invalid);

    double total(EntryType type) => params.entries
        .where((e) => e.type == type)
        .fold(0.0, (sum, e) => sum + e.amount);

    final income = total(EntryType.income);
    final rule = params.rule;

    return Success(
      BudgetSummary(
        income: income,
        fixedExpenses: EnvelopeSummary(
          type: EntryType.fixedExpense,
          budget: income * rule.fixedExpensePct,
          spent: total(EntryType.fixedExpense),
        ),
        investments: EnvelopeSummary(
          type: EntryType.investment,
          budget: income * rule.investmentPct,
          spent: total(EntryType.investment),
        ),
        recurringExpenses: EnvelopeSummary(
          type: EntryType.recurringExpense,
          budget: income * rule.recurringExpensePct,
          spent: total(EntryType.recurringExpense),
        ),
        daysRemaining: params.period.daysRemaining(params.now),
      ),
    );
  }
}

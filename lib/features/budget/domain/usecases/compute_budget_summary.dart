import 'dart:math' as math;

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

/// Regra de negócio central do orçamento (cascata dinâmica):
///
/// ```
/// fixasOrc        = ganho × fixedPct
/// apósFixas       = ganho − fixasGastas
/// investOrc       = apósFixas × investmentPct
/// recorrentesOrc  = apósFixas − investimentosFeitos
/// ```
///
/// O que não for gasto em fixas ou investimentos sobra, automaticamente,
/// para as despesas recorrentes.
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

    final rule = params.rule;
    final income = total(EntryType.income);
    final fixedSpent = total(EntryType.fixedExpense);
    final investmentSpent = total(EntryType.investment);
    final recurringSpent = total(EntryType.recurringExpense);

    final afterFixed = math.max(0.0, income - fixedSpent);

    return Success(
      BudgetSummary(
        income: income,
        fixedExpenses: EnvelopeSummary(
          type: EntryType.fixedExpense,
          budget: income * rule.fixedExpensePct,
          spent: fixedSpent,
        ),
        investments: EnvelopeSummary(
          type: EntryType.investment,
          budget: afterFixed * rule.investmentPct,
          spent: investmentSpent,
        ),
        recurringExpenses: EnvelopeSummary(
          type: EntryType.recurringExpense,
          budget: math.max(0.0, afterFixed - investmentSpent),
          spent: recurringSpent,
        ),
        daysRemaining: params.period.daysRemaining(params.now),
      ),
    );
  }
}

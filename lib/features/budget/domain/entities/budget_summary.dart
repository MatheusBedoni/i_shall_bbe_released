import 'entry_type.dart';

/// Situação de um envelope (fixas, investimentos ou recorrentes).
final class EnvelopeSummary {
  const EnvelopeSummary({
    required this.type,
    required this.budget,
    required this.spent,
  });

  final EntryType type;
  final double budget;
  final double spent;

  double get remaining => budget - spent;

  /// Fração utilizada (0 quando não há orçamento).
  double get usedFraction => budget <= 0 ? (spent > 0 ? 1 : 0) : spent / budget;

  bool get isOverBudget => spent > budget;
}

/// Resumo calculado de um período. Objeto de valor, sem lógica de I/O.
final class BudgetSummary {
  const BudgetSummary({
    required this.income,
    required this.fixedExpenses,
    required this.investments,
    required this.recurringExpenses,
    required this.daysRemaining,
  });

  final double income;
  final EnvelopeSummary fixedExpenses;
  final EnvelopeSummary investments;
  final EnvelopeSummary recurringExpenses;
  final int daysRemaining;

  double get totalSpent =>
      fixedExpenses.spent + investments.spent + recurringExpenses.spent;

  /// Ganho menos tudo que já foi lançado.
  double get finalBalance => income - totalSpent;

  /// Quanto ainda pode ser gasto por dia no envelope de recorrentes.
  double get dailyAllowance {
    if (daysRemaining <= 0) return 0;
    final remaining = recurringExpenses.remaining;
    return remaining <= 0 ? 0 : remaining / daysRemaining;
  }

  EnvelopeSummary envelope(EntryType type) => switch (type) {
        EntryType.fixedExpense => fixedExpenses,
        EntryType.investment => investments,
        EntryType.recurringExpense => recurringExpenses,
        EntryType.income =>
          throw ArgumentError('Ganhos não possuem envelope.'),
      };

  List<EnvelopeSummary> get envelopes =>
      [fixedExpenses, investments, recurringExpenses];
}

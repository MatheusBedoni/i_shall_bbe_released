/// Categoria de um lançamento do orçamento mensal.
enum EntryType {
  income('income', 'Ganhos Mensais'),
  fixedExpense('fixed_expense', 'Despesas Fixas'),
  investment('investment', 'Investimentos'),
  recurringExpense('recurring_expense', 'Despesas Recorrentes');

  const EntryType(this.storageKey, this.label);

  /// Valor persistido (estável, independente do nome do enum).
  final String storageKey;
  final String label;

  bool get isExpense => this != income;

  /// Tipos que possuem um envelope de orçamento.
  static const budgeted = [fixedExpense, investment, recurringExpense];

  static EntryType fromStorageKey(String key) =>
      values.firstWhere((t) => t.storageKey == key, orElse: () => recurringExpense);
}

/// Período mensal do orçamento (ano + mês).
final class BudgetPeriod implements Comparable<BudgetPeriod> {
  const BudgetPeriod({required this.year, required this.month})
      : assert(month >= 1 && month <= 12);

  factory BudgetPeriod.fromDate(DateTime date) =>
      BudgetPeriod(year: date.year, month: date.month);

  factory BudgetPeriod.now() => BudgetPeriod.fromDate(DateTime.now());

  /// Reconstrói a partir da chave `"2025-12"`.
  factory BudgetPeriod.parse(String key) {
    final parts = key.split('-');
    return BudgetPeriod(year: int.parse(parts[0]), month: int.parse(parts[1]));
  }

  final int year;
  final int month;

  /// Chave estável para persistência e agrupamento, ex.: `"2025-12"`.
  String get key => '$year-${month.toString().padLeft(2, '0')}';

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  DateTime get firstDay => DateTime(year, month);
  DateTime get lastDay => DateTime(year, month, daysInMonth);

  BudgetPeriod get previous =>
      month == 1 ? BudgetPeriod(year: year - 1, month: 12) : BudgetPeriod(year: year, month: month - 1);

  BudgetPeriod get next =>
      month == 12 ? BudgetPeriod(year: year + 1, month: 1) : BudgetPeriod(year: year, month: month + 1);

  bool contains(DateTime date) => date.year == year && date.month == month;

  /// Dias que ainda restam no período a partir de [now] (inclusive hoje).
  /// Mês futuro: todos os dias. Mês passado: zero.
  int daysRemaining(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(firstDay)) return daysInMonth;
    if (today.isAfter(lastDay)) return 0;
    return daysInMonth - today.day + 1;
  }

  static const monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  String get monthName => monthNames[month - 1];
  String get label => '$monthName $year';

  @override
  int compareTo(BudgetPeriod other) =>
      year != other.year ? year.compareTo(other.year) : month.compareTo(other.month);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => key;
}

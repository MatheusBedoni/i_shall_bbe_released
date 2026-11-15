import 'budget_period.dart';
import 'entry_type.dart';

/// Um lançamento (ganho ou despesa) dentro de um período.
final class BudgetEntry {
  const BudgetEntry({
    required this.id,
    required this.period,
    required this.type,
    required this.description,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final BudgetPeriod period;
  final EntryType type;
  final String description;
  final double amount;
  final DateTime createdAt;

  BudgetEntry copyWith({
    String? id,
    BudgetPeriod? period,
    EntryType? type,
    String? description,
    double? amount,
    DateTime? createdAt,
  }) =>
      BudgetEntry(
        id: id ?? this.id,
        period: period ?? this.period,
        type: type ?? this.type,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetEntry &&
          other.id == id &&
          other.period == period &&
          other.type == type &&
          other.description == description &&
          other.amount == amount &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, period, type, description, amount, createdAt);
}

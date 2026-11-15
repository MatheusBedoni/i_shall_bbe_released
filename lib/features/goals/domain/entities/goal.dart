/// Meta financeira (ex.: reserva de emergência, viagem, aposentadoria).
final class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.monthlyContribution,
    required this.annualRate,
    this.deadline,
  });

  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final double monthlyContribution;

  /// Rentabilidade anual esperada, em fração (0.10 = 10% a.a.).
  final double annualRate;
  final DateTime? deadline;

  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1).toDouble();

  bool get isReached => currentAmount >= targetAmount;

  Goal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    double? monthlyContribution,
    double? annualRate,
    DateTime? deadline,
  }) =>
      Goal(
        id: id ?? this.id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        monthlyContribution: monthlyContribution ?? this.monthlyContribution,
        annualRate: annualRate ?? this.annualRate,
        deadline: deadline ?? this.deadline,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goal &&
          other.id == id &&
          other.name == name &&
          other.targetAmount == targetAmount &&
          other.currentAmount == currentAmount &&
          other.monthlyContribution == monthlyContribution &&
          other.annualRate == annualRate &&
          other.deadline == deadline;

  @override
  int get hashCode => Object.hash(
        id, name, targetAmount, currentAmount, monthlyContribution, annualRate, deadline,
      );
}

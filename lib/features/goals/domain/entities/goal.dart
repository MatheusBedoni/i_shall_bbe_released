/// Meta financeira (ex.: reserva de emergência, viagem, aposentadoria).
///
/// O saldo de uma meta soma duas fontes: [currentAmount], informado à mão
/// (dinheiro guardado fora da carteira), e o valor atual dos ativos da
/// carteira vinculados em [linkedAssetIds]. A entidade guarda só o que é
/// persistido; a soma e a projeção ficam em `GoalSnapshot`, montado por
/// `ComputeGoalSnapshots`.
final class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.monthlyContribution,
    required this.annualRate,
    this.deadline,
    this.linkedAssetIds = const [],
  });

  final String id;
  final String name;
  final double targetAmount;

  /// Saldo informado manualmente (fora da carteira). Para metas vinculadas é
  /// um complemento; o grosso vem dos ativos.
  final double currentAmount;

  /// Aporte mensal planejado, usado na projeção.
  final double monthlyContribution;

  /// Rentabilidade anual esperada, em fração (0.10 = 10% a.a.).
  final double annualRate;
  final DateTime? deadline;

  /// Ids dos ativos da carteira cujo valor atual conta para esta meta.
  final List<String> linkedAssetIds;

  bool get isLinked => linkedAssetIds.isNotEmpty;

  /// Progresso considerando só [currentAmount]. Para o progresso real de uma
  /// meta vinculada use `GoalSnapshot.progress`.
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
    bool clearDeadline = false,
    List<String>? linkedAssetIds,
  }) =>
      Goal(
        id: id ?? this.id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        monthlyContribution: monthlyContribution ?? this.monthlyContribution,
        annualRate: annualRate ?? this.annualRate,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        linkedAssetIds: linkedAssetIds ?? this.linkedAssetIds,
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
          other.deadline == deadline &&
          _sameIds(other.linkedAssetIds, linkedAssetIds);

  @override
  int get hashCode => Object.hash(
        id,
        name,
        targetAmount,
        currentAmount,
        monthlyContribution,
        annualRate,
        deadline,
        Object.hashAll(linkedAssetIds),
      );

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

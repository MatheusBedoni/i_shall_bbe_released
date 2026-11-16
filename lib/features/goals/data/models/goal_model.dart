import '../../../../core/data/sync/doc_record.dart';
import '../../domain/entities/goal.dart';

/// Conversão entre [Goal] e o documento sincronizado (local/Firestore).
abstract final class GoalModel {
  static const fieldName = 'name';
  static const fieldTargetAmount = 'targetAmount';
  static const fieldCurrentAmount = 'currentAmount';
  static const fieldMonthlyContribution = 'monthlyContribution';
  static const fieldAnnualRate = 'annualRate';
  static const fieldDeadline = 'deadline';
  static const fieldLinkedAssetIds = 'linkedAssetIds';

  static Goal fromRecord(DocRecord doc) => fromMap(doc.id, doc.data);

  static Goal fromMap(String id, DocData data) {
    final deadline = data[fieldDeadline];
    final linked = data[fieldLinkedAssetIds];
    return Goal(
      id: id,
      name: (data[fieldName] as String?) ?? '',
      targetAmount: (data[fieldTargetAmount] as num?)?.toDouble() ?? 0,
      currentAmount: (data[fieldCurrentAmount] as num?)?.toDouble() ?? 0,
      monthlyContribution:
          (data[fieldMonthlyContribution] as num?)?.toDouble() ?? 0,
      annualRate: (data[fieldAnnualRate] as num?)?.toDouble() ?? 0,
      deadline: deadline is DateTime ? deadline : null,
      linkedAssetIds: linked is List
          ? linked.whereType<String>().toList(growable: false)
          : const [],
    );
  }

  static DocData toMap(Goal goal) => {
        fieldName: goal.name,
        fieldTargetAmount: goal.targetAmount,
        fieldCurrentAmount: goal.currentAmount,
        fieldMonthlyContribution: goal.monthlyContribution,
        fieldAnnualRate: goal.annualRate,
        fieldDeadline: goal.deadline,
        fieldLinkedAssetIds: List<String>.of(goal.linkedAssetIds),
      };
}

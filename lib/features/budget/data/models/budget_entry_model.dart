import '../../../../core/data/sync/doc_record.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_period.dart';
import '../../domain/entities/entry_type.dart';

/// Conversão entre [BudgetEntry] e o documento sincronizado (local/Firestore).
abstract final class BudgetEntryModel {
  static const fieldPeriod = 'period';
  static const fieldType = 'type';
  static const fieldDescription = 'description';
  static const fieldAmount = 'amount';
  static const fieldCreatedAt = 'createdAt';

  static BudgetEntry fromRecord(DocRecord doc) => fromMap(doc.id, doc.data);

  static BudgetEntry fromMap(String id, DocData data) {
    final createdAt = data[fieldCreatedAt];
    return BudgetEntry(
      id: id,
      period: BudgetPeriod.parse(data[fieldPeriod] as String),
      type: EntryType.fromStorageKey(data[fieldType] as String),
      description: (data[fieldDescription] as String?) ?? '',
      amount: (data[fieldAmount] as num?)?.toDouble() ?? 0,
      createdAt: createdAt is DateTime ? createdAt : DateTime.now(),
    );
  }

  static DocData toMap(BudgetEntry entry) => {
        fieldPeriod: entry.period.key,
        fieldType: entry.type.storageKey,
        fieldDescription: entry.description.trim(),
        fieldAmount: entry.amount,
        fieldCreatedAt: entry.createdAt,
      };
}

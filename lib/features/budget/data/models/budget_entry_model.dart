import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_period.dart';
import '../../domain/entities/entry_type.dart';

/// Conversão entre [BudgetEntry] e documentos do Firestore.
abstract final class BudgetEntryModel {
  static const fieldPeriod = 'period';
  static const fieldType = 'type';
  static const fieldDescription = 'description';
  static const fieldAmount = 'amount';
  static const fieldCreatedAt = 'createdAt';

  static BudgetEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final createdAt = data[fieldCreatedAt];
    return BudgetEntry(
      id: doc.id,
      period: BudgetPeriod.parse(data[fieldPeriod] as String),
      type: EntryType.fromStorageKey(data[fieldType] as String),
      description: (data[fieldDescription] as String?) ?? '',
      amount: (data[fieldAmount] as num?)?.toDouble() ?? 0,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }

  static Map<String, dynamic> toMap(BudgetEntry entry) => {
        fieldPeriod: entry.period.key,
        fieldType: entry.type.storageKey,
        fieldDescription: entry.description.trim(),
        fieldAmount: entry.amount,
        fieldCreatedAt: Timestamp.fromDate(entry.createdAt),
      };
}

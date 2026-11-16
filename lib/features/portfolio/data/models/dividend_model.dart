import '../../../../core/data/sync/doc_record.dart';
import '../../domain/entities/dividend.dart';

/// Conversão entre [Dividend] e o documento sincronizado.
abstract final class DividendModel {
  static const fieldAssetId = 'assetId';
  static const fieldType = 'type';
  static const fieldAmount = 'amount';
  static const fieldDate = 'date';

  static Dividend fromRecord(DocRecord doc) => fromMap(doc.id, doc.data);

  static Dividend fromMap(String id, DocData data) {
    final date = data[fieldDate];
    return Dividend(
      id: id,
      assetId: (data[fieldAssetId] as String?) ?? '',
      type: DividendType.fromStorageKey((data[fieldType] as String?) ?? ''),
      amount: (data[fieldAmount] as num?)?.toDouble() ?? 0,
      date: date is DateTime ? date : DateTime.now(),
    );
  }

  static DocData toMap(Dividend d) => {
        fieldAssetId: d.assetId,
        fieldType: d.type.storageKey,
        fieldAmount: d.amount,
        fieldDate: d.date,
      };
}

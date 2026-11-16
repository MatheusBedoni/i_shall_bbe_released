import '../../../../core/data/sync/doc_record.dart';
import '../../domain/entities/asset_transaction.dart';

/// Conversão entre [AssetTransaction] e o documento sincronizado.
abstract final class AssetTransactionModel {
  static const fieldAssetId = 'assetId';
  static const fieldType = 'type';
  static const fieldQuantity = 'quantity';
  static const fieldUnitPrice = 'unitPrice';
  static const fieldFees = 'fees';
  static const fieldDate = 'date';

  static AssetTransaction fromRecord(DocRecord doc) => fromMap(doc.id, doc.data);

  static AssetTransaction fromMap(String id, DocData data) {
    final date = data[fieldDate];
    return AssetTransaction(
      id: id,
      assetId: (data[fieldAssetId] as String?) ?? '',
      type: TransactionType.fromStorageKey((data[fieldType] as String?) ?? ''),
      quantity: (data[fieldQuantity] as num?)?.toDouble() ?? 0,
      unitPrice: (data[fieldUnitPrice] as num?)?.toDouble() ?? 0,
      fees: (data[fieldFees] as num?)?.toDouble() ?? 0,
      date: date is DateTime ? date : DateTime.now(),
    );
  }

  static DocData toMap(AssetTransaction tx) => {
        fieldAssetId: tx.assetId,
        fieldType: tx.type.storageKey,
        fieldQuantity: tx.quantity,
        fieldUnitPrice: tx.unitPrice,
        fieldFees: tx.fees,
        fieldDate: tx.date,
      };
}

import '../../../../core/data/sync/doc_record.dart';
import '../../domain/entities/asset.dart';

/// Conversão entre [Asset] e o documento sincronizado (local/Firestore).
abstract final class AssetModel {
  static const fieldTicker = 'ticker';
  static const fieldName = 'name';
  static const fieldClass = 'assetClass';
  static const fieldCurrency = 'currency';

  static Asset fromRecord(DocRecord doc) => fromMap(doc.id, doc.data);

  static Asset fromMap(String id, DocData data) => Asset(
        id: id,
        ticker: (data[fieldTicker] as String?) ?? '',
        name: (data[fieldName] as String?) ?? '',
        assetClass:
            AssetClass.fromStorageKey((data[fieldClass] as String?) ?? ''),
        currency: (data[fieldCurrency] as String?) ?? 'BRL',
      );

  static DocData toMap(Asset asset) => {
        fieldTicker: asset.ticker,
        fieldName: asset.name,
        fieldClass: asset.assetClass.storageKey,
        fieldCurrency: asset.currency,
      };
}

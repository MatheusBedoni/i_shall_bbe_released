import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_transaction.dart';
import '../../domain/entities/dividend.dart';

/// Fonte de dados da carteira. A implementação padrão é local
/// (`LocalPortfolioDataSource`), sincronizada com o Firestore pelo `SyncEngine`.
abstract interface class PortfolioDataSource {
  Stream<List<Asset>> watchAssets();
  Future<Asset> addAsset(Asset asset);
  Future<void> updateAsset(Asset asset);
  Future<void> deleteAsset(String assetId);

  Stream<List<AssetTransaction>> watchTransactions();
  Future<AssetTransaction> addTransaction(AssetTransaction tx);
  Future<void> updateTransaction(AssetTransaction tx);
  Future<void> deleteTransaction(String txId);

  Stream<List<Dividend>> watchDividends();
  Future<Dividend> addDividend(Dividend dividend);
  Future<void> updateDividend(Dividend dividend);
  Future<void> deleteDividend(String dividendId);
}

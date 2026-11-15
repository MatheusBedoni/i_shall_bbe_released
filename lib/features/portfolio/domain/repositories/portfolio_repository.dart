import '../../../../core/utils/result.dart';
import '../entities/asset.dart';
import '../entities/asset_transaction.dart';
import '../entities/dividend.dart';

/// Persistência da carteira do usuário corrente.
abstract interface class PortfolioRepository {
  Stream<Result<List<Asset>>> watchAssets();
  Future<Result<Asset>> addAsset(Asset asset);
  Future<Result<void>> updateAsset(Asset asset);

  /// Remove o ativo e tudo que depende dele (transações e proventos).
  Future<Result<void>> deleteAsset(String assetId);

  Stream<Result<List<AssetTransaction>>> watchTransactions();
  Future<Result<AssetTransaction>> addTransaction(AssetTransaction tx);
  Future<Result<void>> updateTransaction(AssetTransaction tx);
  Future<Result<void>> deleteTransaction(String txId);

  Stream<Result<List<Dividend>>> watchDividends();
  Future<Result<Dividend>> addDividend(Dividend dividend);
  Future<Result<void>> updateDividend(Dividend dividend);
  Future<Result<void>> deleteDividend(String dividendId);
}

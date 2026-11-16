import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_transaction.dart';
import '../../domain/entities/dividend.dart';
import '../../domain/repositories/portfolio_repository.dart';
import '../datasources/portfolio_data_source.dart';

final class PortfolioRepositoryImpl
    with RepositoryGuard
    implements PortfolioRepository {
  const PortfolioRepositoryImpl(this._ds);
  final PortfolioDataSource _ds;

  @override
  Stream<Result<List<Asset>>> watchAssets() => wrapStream(_ds.watchAssets);

  @override
  Future<Result<Asset>> addAsset(Asset asset) =>
      guard(() => _ds.addAsset(asset));

  @override
  Future<Result<void>> updateAsset(Asset asset) =>
      guard(() => _ds.updateAsset(asset));

  @override
  Future<Result<void>> deleteAsset(String assetId) =>
      guard(() => _ds.deleteAsset(assetId));

  @override
  Stream<Result<List<AssetTransaction>>> watchTransactions() =>
      wrapStream(_ds.watchTransactions);

  @override
  Future<Result<AssetTransaction>> addTransaction(AssetTransaction tx) =>
      guard(() => _ds.addTransaction(tx));

  @override
  Future<Result<void>> updateTransaction(AssetTransaction tx) =>
      guard(() => _ds.updateTransaction(tx));

  @override
  Future<Result<void>> deleteTransaction(String txId) =>
      guard(() => _ds.deleteTransaction(txId));

  @override
  Stream<Result<List<Dividend>>> watchDividends() =>
      wrapStream(_ds.watchDividends);

  @override
  Future<Result<Dividend>> addDividend(Dividend dividend) =>
      guard(() => _ds.addDividend(dividend));

  @override
  Future<Result<void>> updateDividend(Dividend dividend) =>
      guard(() => _ds.updateDividend(dividend));

  @override
  Future<Result<void>> deleteDividend(String dividendId) =>
      guard(() => _ds.deleteDividend(dividendId));
}

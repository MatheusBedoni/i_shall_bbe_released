import 'package:sembast/sembast.dart';

import '../../../../core/data/local/local_database.dart';
import '../../../../core/data/sync/doc_record.dart';
import '../../../../core/data/sync/synced_collection.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_transaction.dart';
import '../../domain/entities/dividend.dart';
import '../models/asset_model.dart';
import '../models/asset_transaction_model.dart';
import '../models/dividend_model.dart';
import 'portfolio_data_source.dart';

/// Carteira no banco local, espelhada em:
/// ```
/// users/{uid}/assets/{id}
/// users/{uid}/transactions/{id}
/// users/{uid}/dividends/{id}
/// ```
final class LocalPortfolioDataSource implements PortfolioDataSource {
  LocalPortfolioDataSource(
    LocalDatabase local, {
    DateTime Function()? clock,
    String Function()? newId,
  })  : _assets = SyncedCollection(local, SyncCollections.assets, clock: clock),
        _transactions =
            SyncedCollection(local, SyncCollections.transactions, clock: clock),
        _dividends =
            SyncedCollection(local, SyncCollections.dividends, clock: clock),
        _newId = newId ?? newDocId;

  final SyncedCollection _assets;
  final SyncedCollection _transactions;
  final SyncedCollection _dividends;
  final String Function() _newId;

  // ---------------------------------------------------------------- Ativos

  @override
  Stream<List<Asset>> watchAssets() => _assets
      .watch(finder: Finder(sortOrders: [SortOrder(AssetModel.fieldTicker)]))
      .map((docs) => docs.map(AssetModel.fromRecord).toList());

  @override
  Future<Asset> addAsset(Asset asset) async {
    final saved = asset.copyWith(id: _newId());
    await _assets.put(saved.id, AssetModel.toMap(saved));
    return saved;
  }

  @override
  Future<void> updateAsset(Asset asset) =>
      _assets.put(asset.id, AssetModel.toMap(asset));

  /// Remove o ativo e tudo que depende dele numa única transação local; cada
  /// exclusão vira uma pendência própria na outbox.
  @override
  Future<void> deleteAsset(String assetId) => _assets.transaction((txn) async {
        Finder byAsset(String field) =>
            Finder(filter: Filter.equals(field, assetId));
        final txs = await _transactions.find(
          finder: byAsset(AssetTransactionModel.fieldAssetId),
          client: txn,
        );
        final divs = await _dividends.find(
          finder: byAsset(DividendModel.fieldAssetId),
          client: txn,
        );
        for (final tx in txs) {
          await _transactions.delete(tx.id, txn: txn);
        }
        for (final d in divs) {
          await _dividends.delete(d.id, txn: txn);
        }
        await _assets.delete(assetId, txn: txn);
      });

  // ------------------------------------------------------------ Transações

  @override
  Stream<List<AssetTransaction>> watchTransactions() => _transactions
      .watch(
        finder: Finder(
          sortOrders: [SortOrder(AssetTransactionModel.fieldDate, false)],
        ),
      )
      .map((docs) => docs.map(AssetTransactionModel.fromRecord).toList());

  @override
  Future<AssetTransaction> addTransaction(AssetTransaction tx) async {
    final saved = AssetTransaction(
      id: _newId(),
      assetId: tx.assetId,
      type: tx.type,
      quantity: tx.quantity,
      unitPrice: tx.unitPrice,
      date: tx.date,
      fees: tx.fees,
    );
    await _transactions.put(saved.id, AssetTransactionModel.toMap(saved));
    return saved;
  }

  @override
  Future<void> updateTransaction(AssetTransaction tx) =>
      _transactions.put(tx.id, AssetTransactionModel.toMap(tx));

  @override
  Future<void> deleteTransaction(String txId) => _transactions.delete(txId);

  // ------------------------------------------------------------- Proventos

  @override
  Stream<List<Dividend>> watchDividends() => _dividends
      .watch(
        finder: Finder(sortOrders: [SortOrder(DividendModel.fieldDate, false)]),
      )
      .map((docs) => docs.map(DividendModel.fromRecord).toList());

  @override
  Future<Dividend> addDividend(Dividend dividend) async {
    final saved = Dividend(
      id: _newId(),
      assetId: dividend.assetId,
      type: dividend.type,
      amount: dividend.amount,
      date: dividend.date,
    );
    await _dividends.put(saved.id, DividendModel.toMap(saved));
    return saved;
  }

  @override
  Future<void> updateDividend(Dividend dividend) =>
      _dividends.put(dividend.id, DividendModel.toMap(dividend));

  @override
  Future<void> deleteDividend(String dividendId) =>
      _dividends.delete(dividendId);
}

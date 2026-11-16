import 'dart:async';

import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/core/utils/result.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset_transaction.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/dividend.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/quote.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/ticker_suggestion.dart';
import 'package:i_shall_be_released/features/portfolio/domain/repositories/portfolio_repository.dart';
import 'package:i_shall_be_released/features/portfolio/domain/repositories/quote_repository.dart';

/// Carteira em memória que imita o comportamento reativo do Firestore.
class InMemoryPortfolioRepository implements PortfolioRepository {
  final assets = <Asset>[];
  final transactions = <AssetTransaction>[];
  final dividends = <Dividend>[];

  final _assetsCtrl = StreamController<Result<List<Asset>>>.broadcast();
  final _txsCtrl = StreamController<Result<List<AssetTransaction>>>.broadcast();
  final _divsCtrl = StreamController<Result<List<Dividend>>>.broadcast();
  int _seq = 0;

  void _emitAssets() => _assetsCtrl.add(Success(List.of(assets)));
  void _emitTxs() => _txsCtrl.add(Success(List.of(transactions)));
  void _emitDivs() => _divsCtrl.add(Success(List.of(dividends)));

  @override
  Stream<Result<List<Asset>>> watchAssets() {
    scheduleMicrotask(_emitAssets);
    return _assetsCtrl.stream;
  }

  @override
  Future<Result<Asset>> addAsset(Asset asset) async {
    final saved = asset.copyWith(id: 'a${_seq++}');
    assets.add(saved);
    _emitAssets();
    return Success(saved);
  }

  @override
  Future<Result<void>> updateAsset(Asset asset) async {
    final i = assets.indexWhere((a) => a.id == asset.id);
    if (i < 0) return const Error(ServerFailure('não encontrado'));
    assets[i] = asset;
    _emitAssets();
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAsset(String assetId) async {
    assets.removeWhere((a) => a.id == assetId);
    transactions.removeWhere((t) => t.assetId == assetId);
    dividends.removeWhere((d) => d.assetId == assetId);
    _emitAssets();
    _emitTxs();
    _emitDivs();
    return const Success(null);
  }

  @override
  Stream<Result<List<AssetTransaction>>> watchTransactions() {
    scheduleMicrotask(_emitTxs);
    return _txsCtrl.stream;
  }

  @override
  Future<Result<AssetTransaction>> addTransaction(AssetTransaction tx) async {
    final saved = AssetTransaction(
      id: 't${_seq++}',
      assetId: tx.assetId,
      type: tx.type,
      quantity: tx.quantity,
      unitPrice: tx.unitPrice,
      fees: tx.fees,
      date: tx.date,
    );
    transactions.add(saved);
    _emitTxs();
    return Success(saved);
  }

  @override
  Future<Result<void>> updateTransaction(AssetTransaction tx) async {
    final i = transactions.indexWhere((t) => t.id == tx.id);
    if (i < 0) return const Error(ServerFailure('não encontrado'));
    transactions[i] = tx;
    _emitTxs();
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteTransaction(String txId) async {
    transactions.removeWhere((t) => t.id == txId);
    _emitTxs();
    return const Success(null);
  }

  @override
  Stream<Result<List<Dividend>>> watchDividends() {
    scheduleMicrotask(_emitDivs);
    return _divsCtrl.stream;
  }

  @override
  Future<Result<Dividend>> addDividend(Dividend dividend) async {
    final saved = Dividend(
      id: 'd${_seq++}',
      assetId: dividend.assetId,
      type: dividend.type,
      amount: dividend.amount,
      date: dividend.date,
    );
    dividends.add(saved);
    _emitDivs();
    return Success(saved);
  }

  @override
  Future<Result<void>> updateDividend(Dividend dividend) async {
    final i = dividends.indexWhere((d) => d.id == dividend.id);
    if (i < 0) return const Error(ServerFailure('não encontrado'));
    dividends[i] = dividend;
    _emitDivs();
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteDividend(String dividendId) async {
    dividends.removeWhere((d) => d.id == dividendId);
    _emitDivs();
    return const Success(null);
  }
}

/// Fonte de cotações programável.
class FakeQuoteRepository implements QuoteRepository {
  Map<String, Quote> quotes = {};
  List<TickerSuggestion> suggestions = const [];
  Failure? failure;
  int calls = 0;
  List<String> lastRequested = const [];

  @override
  Future<Result<Map<String, Quote>>> getQuotes(List<String> tickers) async {
    calls++;
    lastRequested = tickers;
    final f = failure;
    if (f != null) return Error(f);
    return Success({
      for (final t in tickers)
        if (quotes.containsKey(t)) t: quotes[t]!,
    });
  }

  @override
  Future<Result<List<TickerSuggestion>>> searchTickers(String query) async {
    final f = failure;
    if (f != null) return Error(f);
    return Success(
      suggestions.where((s) => s.ticker.contains(query.toUpperCase())).toList(),
    );
  }
}

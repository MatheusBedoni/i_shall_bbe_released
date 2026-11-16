import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_transaction.dart';
import '../../domain/entities/dividend.dart';
import '../../domain/entities/position.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/ticker_suggestion.dart';
import '../../domain/usecases/portfolio_usecases.dart';

/// Estado da carteira: ativos, transações, proventos, cotações e posições.
final class PortfolioController extends ChangeNotifier {
  PortfolioController({
    required this.watchAssets,
    required this.watchTransactions,
    required this.watchDividends,
    required this.addAsset,
    required this.updateAsset,
    required this.deleteAsset,
    required this.addTransaction,
    required this.updateTransaction,
    required this.deleteTransaction,
    required this.addDividend,
    required this.updateDividend,
    required this.deleteDividend,
    required this.getQuotes,
    required this.searchTickers,
    required this.computePositions,
    DateTime Function()? clock,
    this.quoteCacheTtl = const Duration(minutes: 1),
  }) : _clock = clock ?? DateTime.now;

  final WatchAssets watchAssets;
  final WatchTransactions watchTransactions;
  final WatchDividends watchDividends;
  final AddAsset addAsset;
  final UpdateAsset updateAsset;
  final DeleteAsset deleteAsset;
  final AddTransaction addTransaction;
  final UpdateTransaction updateTransaction;
  final DeleteTransaction deleteTransaction;
  final AddDividend addDividend;
  final UpdateDividend updateDividend;
  final DeleteDividend deleteDividend;
  final GetQuotes getQuotes;
  final SearchTickers searchTickers;
  final ComputePositions computePositions;

  /// Intervalo mínimo entre atualizações automáticas de cotação.
  final Duration quoteCacheTtl;

  final DateTime Function() _clock;

  List<Asset> _assets = const [];
  List<AssetTransaction> _transactions = const [];
  List<Dividend> _dividends = const [];
  Map<String, Quote> _quotes = const {};
  PortfolioSummary? _summary;

  bool _assetsLoaded = false;
  bool _txsLoaded = false;
  bool _divsLoaded = false;
  bool _refreshingQuotes = false;
  DateTime? _quotesUpdatedAt;
  Set<String> _quotedTickers = const {};
  String? _error;
  String? _quoteError;
  String? _message;

  StreamSubscription<Object>? _assetsSub;
  StreamSubscription<Object>? _txsSub;
  StreamSubscription<Object>? _divsSub;

  List<Asset> get assets => _assets;
  List<AssetTransaction> get transactions => _transactions;
  List<Dividend> get dividends => _dividends;
  Map<String, Quote> get quotes => _quotes;
  PortfolioSummary? get summary => _summary;
  bool get loading => !(_assetsLoaded && _txsLoaded && _divsLoaded);
  bool get refreshingQuotes => _refreshingQuotes;
  DateTime? get quotesUpdatedAt => _quotesUpdatedAt;
  String? get error => _error;

  /// Erro da última busca de cotações (não bloqueia a carteira).
  String? get quoteError => _quoteError;

  String? consumeMessage() {
    final m = _message;
    _message = null;
    return m;
  }

  Asset? assetById(String id) {
    for (final a in _assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  Position? positionOf(String assetId) {
    for (final p in _summary?.positions ?? const <Position>[]) {
      if (p.asset.id == assetId) return p;
    }
    return null;
  }

  List<AssetTransaction> transactionsOf(String assetId) =>
      _transactions.where((t) => t.assetId == assetId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Dividend> dividendsOf(String assetId) =>
      _dividends.where((d) => d.assetId == assetId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Posições abertas, maiores primeiro.
  List<Position> get openPositions {
    final list = _summary?.openPositions ?? const <Position>[];
    return list.toList()..sort((a, b) => b.currentValue.compareTo(a.currentValue));
  }

  List<Position> get closedPositions =>
      (_summary?.positions ?? const <Position>[]).where((p) => !p.isOpen).toList();

  Quote? quoteOf(Asset asset) => _quotes[asset.ticker.toUpperCase()];

  void start() {
    _assetsSub ??= watchAssets().listen((r) {
      _assetsLoaded = true;
      r.fold((f) => _setError(f.message), (assets) {
        _assets = assets;
        _error = null;
        _recompute();
        _refreshQuotesIfTickersChanged();
      });
    });
    _txsSub ??= watchTransactions().listen((r) {
      _txsLoaded = true;
      r.fold((f) => _setError(f.message), (txs) {
        _transactions = txs;
        _error = null;
        _recompute();
      });
    });
    _divsSub ??= watchDividends().listen((r) {
      _divsLoaded = true;
      r.fold((f) => _setError(f.message), (divs) {
        _dividends = divs;
        _error = null;
        _recompute();
      });
    });
  }

  // -------------------------------------------------------------- Cotações

  /// Atualiza as cotações. Sem [force], respeita [quoteCacheTtl].
  Future<void> refreshQuotes({bool force = false}) async {
    if (_refreshingQuotes) return;
    final last = _quotesUpdatedAt;
    if (!force && last != null && _clock().difference(last) < quoteCacheTtl) {
      return;
    }
    final quoted = _assets.where((a) => a.assetClass.hasMarketQuote).toList();
    _quotedTickers = quoted.map((a) => a.ticker.toUpperCase()).toSet();
    if (quoted.isEmpty) {
      _quotes = const {};
      _quoteError = null;
      _recompute();
      return;
    }
    _refreshingQuotes = true;
    notifyListeners();
    final result = await getQuotes(quoted);
    _refreshingQuotes = false;
    result.fold(
      (f) => _quoteError = f.message,
      (quotes) {
        // Mantém a última cotação conhecida de tickers que não vieram agora.
        _quotes = {..._quotes, ...quotes};
        _quotesUpdatedAt = _clock();
        _quoteError = null;
      },
    );
    _recompute();
  }

  void _refreshQuotesIfTickersChanged() {
    final current = _assets
        .where((a) => a.assetClass.hasMarketQuote)
        .map((a) => a.ticker.toUpperCase())
        .toSet();
    if (setEquals(current, _quotedTickers)) return;
    unawaited(refreshQuotes(force: true));
  }

  Future<List<TickerSuggestion>> suggestTickers(String query) async {
    final r = await searchTickers(query);
    return r.fold((_) => const [], (list) => list);
  }

  // ---------------------------------------------------------------- Ativos

  Future<bool> createAsset(Asset asset) => _mutate(
        () => addAsset(asset),
        onSuccess: (_) => _message = 'Ativo ${asset.ticker.toUpperCase()} cadastrado.',
      );

  Future<bool> editAsset(Asset asset) => _mutate(() => updateAsset(asset));

  Future<bool> removeAsset(String assetId) => _mutate(
        () => deleteAsset(assetId),
        onSuccess: (_) => _message = 'Ativo removido com suas transações e proventos.',
      );

  // ------------------------------------------------------------ Transações

  Future<bool> createTransaction(AssetTransaction tx) =>
      _mutate(() => addTransaction(tx));

  Future<bool> editTransaction(AssetTransaction tx) =>
      _mutate(() => updateTransaction(tx));

  Future<bool> removeTransaction(String txId) =>
      _mutate(() => deleteTransaction(txId));

  // ------------------------------------------------------------- Proventos

  Future<bool> createDividend(Dividend d) => _mutate(() => addDividend(d));
  Future<bool> editDividend(Dividend d) => _mutate(() => updateDividend(d));
  Future<bool> removeDividend(String id) => _mutate(() => deleteDividend(id));

  // --------------------------------------------------------------- Interno

  void _recompute() {
    final result = computePositions(ComputePositionsParams(
      assets: _assets,
      transactions: _transactions,
      dividends: _dividends,
      quotes: _quotes,
    ));
    result.fold((f) => _error = f.message, (s) => _summary = s);
    notifyListeners();
  }

  Future<bool> _mutate<T>(
    Future<dynamic> Function() action, {
    void Function(T value)? onSuccess,
  }) async {
    final result = await action();
    return result.fold<bool>(
      (failure) {
        _setError(failure.message);
        return false;
      },
      (value) {
        onSuccess?.call(value as T);
        notifyListeners();
        return true;
      },
    );
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _assetsSub?.cancel();
    _txsSub?.cancel();
    _divsSub?.cancel();
    super.dispose();
  }
}

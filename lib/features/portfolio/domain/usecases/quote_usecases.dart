import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/asset.dart';
import '../entities/quote.dart';
import '../entities/ticker_suggestion.dart';
import '../repositories/quote_repository.dart';

/// Busca cotações apenas dos ativos cuja classe tem preço de mercado.
final class GetQuotes implements UseCase<Map<String, Quote>, List<Asset>> {
  const GetQuotes(this._repo);
  final QuoteRepository _repo;

  @override
  Future<Result<Map<String, Quote>>> call(List<Asset> assets) {
    final tickers = assets
        .where((a) => a.assetClass.hasMarketQuote)
        .map((a) => a.ticker.toUpperCase())
        .toSet()
        .toList();
    if (tickers.isEmpty) return Future.value(const Success({}));
    return _repo.getQuotes(tickers);
  }
}

final class SearchTickers implements UseCase<List<TickerSuggestion>, String> {
  const SearchTickers(this._repo);
  final QuoteRepository _repo;

  @override
  Future<Result<List<TickerSuggestion>>> call(String query) {
    final q = query.trim();
    if (q.length < 2) return Future.value(const Success([]));
    return _repo.searchTickers(q);
  }
}

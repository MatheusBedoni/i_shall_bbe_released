import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/ticker_suggestion.dart';
import '../../domain/repositories/quote_repository.dart';
import '../datasources/brapi_quote_data_source.dart';

final class QuoteRepositoryImpl with RepositoryGuard implements QuoteRepository {
  const QuoteRepositoryImpl(this._remote);
  final QuoteRemoteDataSource _remote;

  @override
  Future<Result<Map<String, Quote>>> getQuotes(List<String> tickers) =>
      guard(() => _remote.getQuotes(tickers));

  @override
  Future<Result<List<TickerSuggestion>>> searchTickers(String query) =>
      guard(() => _remote.searchTickers(query));
}

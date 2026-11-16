import '../../../../core/utils/result.dart';
import '../entities/quote.dart';
import '../entities/ticker_suggestion.dart';

/// Fonte de cotações de mercado (ex.: brapi.dev).
abstract interface class QuoteRepository {
  /// Retorna as cotações encontradas, indexadas por ticker (maiúsculo).
  /// Tickers desconhecidos simplesmente não aparecem no mapa.
  Future<Result<Map<String, Quote>>> getQuotes(List<String> tickers);

  /// Busca ativos listados por parte do ticker ou do nome.
  Future<Result<List<TickerSuggestion>>> searchTickers(String query);
}

import '../../../../core/utils/result.dart';
import '../entities/quote.dart';

/// Fonte de cotações de mercado (ex.: brapi.dev).
abstract interface class QuoteRepository {
  /// Retorna as cotações encontradas, indexadas por ticker (maiúsculo).
  /// Tickers desconhecidos simplesmente não aparecem no mapa.
  Future<Result<Map<String, Quote>>> getQuotes(List<String> tickers);
}

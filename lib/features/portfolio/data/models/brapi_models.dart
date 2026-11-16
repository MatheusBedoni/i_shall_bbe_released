import '../../domain/entities/asset.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/ticker_suggestion.dart';

/// Parsing das respostas da brapi.dev. Mantido sem dependência de HTTP para
/// ser testável com JSON puro.
///
/// Cotação: `GET /api/v2/stocks/quote?symbols=PETR4`
/// ```json
/// {"results":[{"requestedSymbol":"PETR4","symbol":"PETR4","changed":false,
///   "data":{"regularMarketPrice":38.1,"regularMarketChangePercent":1.25,
///           "regularMarketTime":"2025-01-10T20:07:00.000Z", ...}}],
///  "requestedAt":"...","took":12}
/// ```
///
/// Busca: `GET /api/v2/tickers?search=PETR`
/// ```json
/// {"results":[{"symbol":"PETR4","name":"PETROBRAS PN","longName":"...",
///   "assetType":"stock","subType":"stock","quote":{"lastPrice":38.1}}], ...}
/// ```
abstract final class BrapiModels {
  /// Extrai as cotações de uma resposta, indexadas pelo ticker **pedido**
  /// (a brapi pode trocar tickers antigos pelos atuais; `requestedSymbol`
  /// garante que a chave bata com o cadastro do usuário).
  static Map<String, Quote> quotesFromJson(Map<String, dynamic> json, {DateTime? now}) {
    final results = json['results'];
    if (results is! List) return const {};
    final out = <String, Quote>{};
    for (final item in results) {
      if (item is! Map) continue;
      final data = item['data'];
      final symbol = (item['symbol'] as String?) ?? '';
      final requested = (item['requestedSymbol'] as String?) ?? symbol;
      final price = data is Map ? _num(data['regularMarketPrice']) : null;
      if (price == null || requested.isEmpty) continue;
      final pct = data is Map ? _num(data['regularMarketChangePercent']) : null;
      final time = data is Map ? data['regularMarketTime'] : null;
      final updatedAt =
          (time is String ? DateTime.tryParse(time) : null) ?? now ?? DateTime.now();
      final key = requested.toUpperCase();
      out[key] = Quote(
        ticker: key,
        price: price,
        changePercent: pct == null ? null : pct / 100,
        updatedAt: updatedAt,
      );
    }
    return out;
  }

  static List<TickerSuggestion> suggestionsFromJson(Map<String, dynamic> json) {
    final results = json['results'];
    if (results is! List) return const [];
    final out = <TickerSuggestion>[];
    for (final item in results) {
      if (item is! Map) continue;
      final symbol = (item['symbol'] as String?) ?? '';
      if (symbol.isEmpty) continue;
      final quote = item['quote'];
      out.add(TickerSuggestion(
        ticker: symbol.toUpperCase(),
        name: (item['longName'] as String?)?.trim().isNotEmpty == true
            ? (item['longName'] as String).trim()
            : ((item['name'] as String?) ?? symbol).trim(),
        assetClass: assetClassFrom(
          assetType: item['assetType'] as String?,
          subType: item['subType'] as String?,
        ),
        lastPrice: quote is Map ? _num(quote['lastPrice']) : null,
      ));
    }
    return out;
  }

  /// Mapeia `assetType`/`subType` da brapi para [AssetClass].
  static AssetClass assetClassFrom({String? assetType, String? subType}) {
    switch (subType) {
      case 'etf':
        return AssetClass.etf;
      case 'bdr':
        return AssetClass.bdr;
      case 'fii':
      case 'fi-infra':
      case 'fi-agro':
      case 'fip':
      case 'fidc':
        return AssetClass.fii;
      case 'stock':
      case 'unit':
        return AssetClass.stock;
    }
    return switch (assetType) {
      'fund' => AssetClass.fii,
      'bdr' => AssetClass.bdr,
      _ => AssetClass.stock,
    };
  }

  static double? _num(Object? v) => v is num ? v.toDouble() : null;
}

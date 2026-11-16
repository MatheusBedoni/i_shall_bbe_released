import 'asset.dart';

/// Resultado de uma busca de tickers na fonte de cotações (ex.: brapi.dev),
/// usado para preencher o cadastro de um ativo com dados reais.
final class TickerSuggestion {
  const TickerSuggestion({
    required this.ticker,
    required this.name,
    required this.assetClass,
    this.lastPrice,
  });

  final String ticker;
  final String name;
  final AssetClass assetClass;
  final double? lastPrice;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TickerSuggestion &&
          other.ticker == ticker &&
          other.name == name &&
          other.assetClass == assetClass &&
          other.lastPrice == lastPrice;

  @override
  int get hashCode => Object.hash(ticker, name, assetClass, lastPrice);
}

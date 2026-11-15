/// Classe de ativo, usada para alocação e agrupamento da carteira.
enum AssetClass {
  stock('stock', 'Ações'),
  fii('fii', 'Fundos Imobiliários'),
  etf('etf', 'ETFs'),
  bdr('bdr', 'BDRs'),
  fixedIncome('fixed_income', 'Renda Fixa'),
  crypto('crypto', 'Criptomoedas'),
  other('other', 'Outros');

  const AssetClass(this.storageKey, this.label);
  final String storageKey;
  final String label;

  /// Classes cujo preço pode ser buscado em uma API de cotações.
  bool get hasMarketQuote =>
      this == stock || this == fii || this == etf || this == bdr || this == crypto;

  static AssetClass fromStorageKey(String key) =>
      values.firstWhere((c) => c.storageKey == key, orElse: () => other);
}

/// Um ativo da carteira (ex.: PETR4, HGLG11, Tesouro Selic 2029).
final class Asset {
  const Asset({
    required this.id,
    required this.ticker,
    required this.name,
    required this.assetClass,
    this.currency = 'BRL',
  });

  final String id;

  /// Código do ativo. Para renda fixa pode ser um identificador livre.
  final String ticker;
  final String name;
  final AssetClass assetClass;
  final String currency;

  Asset copyWith({
    String? id,
    String? ticker,
    String? name,
    AssetClass? assetClass,
    String? currency,
  }) =>
      Asset(
        id: id ?? this.id,
        ticker: ticker ?? this.ticker,
        name: name ?? this.name,
        assetClass: assetClass ?? this.assetClass,
        currency: currency ?? this.currency,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Asset &&
          other.id == id &&
          other.ticker == ticker &&
          other.name == name &&
          other.assetClass == assetClass &&
          other.currency == currency;

  @override
  int get hashCode => Object.hash(id, ticker, name, assetClass, currency);
}

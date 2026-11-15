/// Cotação de mercado de um ticker.
final class Quote {
  const Quote({
    required this.ticker,
    required this.price,
    required this.updatedAt,
    this.changePercent,
  });

  final String ticker;
  final double price;

  /// Variação percentual do dia, em fração (0.012 = +1,2%). Pode ser nula.
  final double? changePercent;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quote &&
          other.ticker == ticker &&
          other.price == price &&
          other.changePercent == changePercent &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(ticker, price, changePercent, updatedAt);
}

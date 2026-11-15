import 'asset.dart';

/// Posição consolidada de um ativo, calculada a partir das transações.
final class Position {
  const Position({
    required this.asset,
    required this.quantity,
    required this.averagePrice,
    required this.realizedPnl,
    required this.dividendsReceived,
    this.currentPrice,
  });

  final Asset asset;
  final double quantity;

  /// Preço médio de aquisição (inclui taxas das compras).
  final double averagePrice;

  /// Lucro/prejuízo já realizado em vendas.
  final double realizedPnl;

  /// Soma de proventos recebidos.
  final double dividendsReceived;

  /// Última cotação conhecida; `null` quando não há cotação (ex.: renda fixa).
  final double? currentPrice;

  bool get isOpen => quantity > 0;

  /// Custo total da posição aberta.
  double get invested => quantity * averagePrice;

  /// Valor de mercado. Sem cotação, assume o custo.
  double get currentValue => quantity * (currentPrice ?? averagePrice);

  double get unrealizedPnl => currentValue - invested;

  /// Fração (0.1 = 10%). Zero quando não há custo.
  double get unrealizedPnlPercent =>
      invested == 0 ? 0 : unrealizedPnl / invested;

  /// Retorno total: não realizado + realizado + proventos.
  double get totalReturn => unrealizedPnl + realizedPnl + dividendsReceived;

  Position copyWith({double? currentPrice}) => Position(
        asset: asset,
        quantity: quantity,
        averagePrice: averagePrice,
        realizedPnl: realizedPnl,
        dividendsReceived: dividendsReceived,
        currentPrice: currentPrice ?? this.currentPrice,
      );
}

/// Visão agregada da carteira.
final class PortfolioSummary {
  const PortfolioSummary({required this.positions});

  final List<Position> positions;

  List<Position> get openPositions => positions.where((p) => p.isOpen).toList();

  double get totalInvested =>
      openPositions.fold(0.0, (s, p) => s + p.invested);

  double get totalCurrentValue =>
      openPositions.fold(0.0, (s, p) => s + p.currentValue);

  double get totalUnrealizedPnl => totalCurrentValue - totalInvested;

  double get totalUnrealizedPnlPercent =>
      totalInvested == 0 ? 0 : totalUnrealizedPnl / totalInvested;

  double get totalRealizedPnl =>
      positions.fold(0.0, (s, p) => s + p.realizedPnl);

  double get totalDividends =>
      positions.fold(0.0, (s, p) => s + p.dividendsReceived);

  /// Fração do valor atual por classe de ativo (soma 1 quando há posições).
  Map<AssetClass, double> get allocationByClass {
    final total = totalCurrentValue;
    final byClass = <AssetClass, double>{};
    for (final p in openPositions) {
      byClass.update(
        p.asset.assetClass,
        (v) => v + p.currentValue,
        ifAbsent: () => p.currentValue,
      );
    }
    if (total == 0) return byClass;
    return {for (final e in byClass.entries) e.key: e.value / total};
  }
}

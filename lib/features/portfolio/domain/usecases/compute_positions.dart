import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/asset.dart';
import '../entities/asset_transaction.dart';
import '../entities/dividend.dart';
import '../entities/position.dart';
import '../entities/quote.dart';

final class ComputePositionsParams {
  const ComputePositionsParams({
    required this.assets,
    required this.transactions,
    this.dividends = const [],
    this.quotes = const {},
  });

  final List<Asset> assets;
  final List<AssetTransaction> transactions;
  final List<Dividend> dividends;

  /// Cotações indexadas por ticker (maiúsculo).
  final Map<String, Quote> quotes;
}

/// Consolida transações em posições usando **preço médio ponderado**:
/// compras recalculam o preço médio (incluindo taxas); vendas reduzem a
/// quantidade, mantêm o preço médio e realizam lucro/prejuízo.
final class ComputePositions
    implements SyncUseCase<PortfolioSummary, ComputePositionsParams> {
  const ComputePositions();

  @override
  Result<PortfolioSummary> call(ComputePositionsParams params) {
    final byAsset = {for (final a in params.assets) a.id: a};
    final positions = <Position>[];

    for (final asset in params.assets) {
      final txs = params.transactions
          .where((t) => t.assetId == asset.id)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      var quantity = 0.0;
      var averagePrice = 0.0;
      var realized = 0.0;

      for (final tx in txs) {
        switch (tx.type) {
          case TransactionType.buy:
            final newQty = quantity + tx.quantity;
            averagePrice = newQty == 0
                ? 0
                : (quantity * averagePrice + tx.netAmount) / newQty;
            quantity = newQty;
          case TransactionType.sell:
            if (tx.quantity > quantity + 1e-9) {
              return Error(ValidationFailure(
                'Venda de ${tx.quantity} ${asset.ticker} maior que a posição ($quantity).',
              ));
            }
            realized += tx.netAmount - tx.quantity * averagePrice;
            quantity -= tx.quantity;
            if (quantity.abs() < 1e-9) {
              quantity = 0;
              averagePrice = 0;
            }
        }
      }

      final dividends = params.dividends
          .where((d) => d.assetId == asset.id)
          .fold(0.0, (s, d) => s + d.amount);

      final quote = params.quotes[asset.ticker.toUpperCase()];

      positions.add(Position(
        asset: asset,
        quantity: quantity,
        averagePrice: averagePrice,
        realizedPnl: realized,
        dividendsReceived: dividends,
        currentPrice: quote?.price,
      ));
    }

    // Transações órfãs (ativo apagado) são ignoradas, mas sinalizadas.
    final orphan = params.transactions.any((t) => !byAsset.containsKey(t.assetId));
    if (orphan) {
      return const Error(ValidationFailure(
        'Existem transações de ativos que não estão mais na carteira.',
      ));
    }

    return Success(PortfolioSummary(positions: positions));
  }
}

import 'asset.dart';
import 'asset_transaction.dart';

/// Um aporte (compra) visto pelo orçamento mensal: a transação junto com o
/// ativo a que pertence. É o elo entre a carteira e o envelope de
/// investimentos do mês.
final class Contribution {
  const Contribution({required this.transaction, required this.asset});

  final AssetTransaction transaction;
  final Asset asset;

  String get id => transaction.id;
  DateTime get date => transaction.date;

  /// Dinheiro que saiu do orçamento (custo total, com taxas).
  double get amount => transaction.netAmount;

  /// Ativos sem cotação (renda fixa, outros) são lançados só pelo valor,
  /// sem quantidade e preço unitário.
  bool get isAmountOnly => !asset.assetClass.hasMarketQuote;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contribution &&
          other.transaction == transaction &&
          other.asset == asset;

  @override
  int get hashCode => Object.hash(transaction, asset);
}

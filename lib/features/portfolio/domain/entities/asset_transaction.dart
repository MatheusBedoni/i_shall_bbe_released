enum TransactionType {
  buy('buy', 'Compra'),
  sell('sell', 'Venda');

  const TransactionType(this.storageKey, this.label);
  final String storageKey;
  final String label;

  static TransactionType fromStorageKey(String key) =>
      values.firstWhere((t) => t.storageKey == key, orElse: () => buy);
}

/// Uma operação de compra ou venda de um ativo (aporte ou resgate).
final class AssetTransaction {
  const AssetTransaction({
    required this.id,
    required this.assetId,
    required this.type,
    required this.quantity,
    required this.unitPrice,
    required this.date,
    this.fees = 0,
  });

  final String id;
  final String assetId;
  final TransactionType type;
  final double quantity;
  final double unitPrice;
  final DateTime date;

  /// Taxas e corretagem, somadas ao custo na compra e deduzidas na venda.
  final double fees;

  /// Valor bruto da operação (sem taxas).
  double get grossAmount => quantity * unitPrice;

  /// Custo total de aquisição (compra) ou valor líquido recebido (venda).
  double get netAmount =>
      type == TransactionType.buy ? grossAmount + fees : grossAmount - fees;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetTransaction &&
          other.id == id &&
          other.assetId == assetId &&
          other.type == type &&
          other.quantity == quantity &&
          other.unitPrice == unitPrice &&
          other.date == date &&
          other.fees == fees;

  @override
  int get hashCode =>
      Object.hash(id, assetId, type, quantity, unitPrice, date, fees);
}

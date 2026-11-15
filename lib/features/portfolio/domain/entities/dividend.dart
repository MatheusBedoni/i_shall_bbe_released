enum DividendType {
  dividend('dividend', 'Dividendo'),
  jcp('jcp', 'JCP'),
  income('income', 'Rendimento'),
  other('other', 'Outro');

  const DividendType(this.storageKey, this.label);
  final String storageKey;
  final String label;

  static DividendType fromStorageKey(String key) =>
      values.firstWhere((t) => t.storageKey == key, orElse: () => other);
}

/// Provento recebido de um ativo (dividendo, JCP, rendimento de FII, etc.).
final class Dividend {
  const Dividend({
    required this.id,
    required this.assetId,
    required this.type,
    required this.amount,
    required this.date,
  });

  final String id;
  final String assetId;
  final DividendType type;

  /// Valor total líquido recebido.
  final double amount;
  final DateTime date;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dividend &&
          other.id == id &&
          other.assetId == assetId &&
          other.type == type &&
          other.amount == amount &&
          other.date == date;

  @override
  int get hashCode => Object.hash(id, assetId, type, amount, date);
}

/// Mapa de campos de um documento, com [DateTime] para datas. É o formato
/// neutro que trafega entre o banco local, o motor de sync e o Firestore;
/// cada lado converte datas para o seu próprio tipo de timestamp.
typedef DocData = Map<String, Object?>;

/// Um documento (id + campos) de uma coleção sincronizada, independente de
/// onde está armazenado.
final class DocRecord {
  const DocRecord(this.id, this.data);

  final String id;
  final DocData data;

  /// Instante da última modificação, usado para resolver conflitos
  /// (last-write-wins). Documentos antigos sem o campo contam como época 0.
  DateTime get updatedAt =>
      data[SyncFields.updatedAt] as DateTime? ??
      DateTime.fromMillisecondsSinceEpoch(0);

  @override
  String toString() => 'DocRecord($id, $data)';
}

/// Campos de controle gravados em todo documento sincronizado.
abstract final class SyncFields {
  static const updatedAt = 'updatedAt';
}

/// Nomes das coleções sincronizadas em `users/{uid}/<coleção>`.
abstract final class SyncCollections {
  static const budgetEntries = 'budget_entries';
  static const settings = 'settings';
  static const assets = 'assets';
  static const transactions = 'transactions';
  static const dividends = 'dividends';
  static const goals = 'goals';

  static const all = [
    budgetEntries,
    settings,
    assets,
    transactions,
    dividends,
    goals,
  ];
}

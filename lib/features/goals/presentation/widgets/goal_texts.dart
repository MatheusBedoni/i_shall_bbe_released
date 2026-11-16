/// Textos derivados para as telas de metas.
abstract final class GoalTexts {
  /// "3 meses", "1 ano", "2 anos e 4 meses".
  static String months(int months) {
    if (months <= 0) return 'agora';
    final years = months ~/ 12;
    final rem = months % 12;
    final y = years == 0 ? null : (years == 1 ? '1 ano' : '$years anos');
    final m = rem == 0 ? null : (rem == 1 ? '1 mês' : '$rem meses');
    if (y != null && m != null) return '$y e $m';
    return y ?? m!;
  }
}

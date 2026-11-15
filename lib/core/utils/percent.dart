/// Utilitários de porcentagem.
abstract final class Percent {
  static String format(double fraction, {int decimals = 1}) =>
      '${(fraction * 100).toStringAsFixed(decimals)}%';
}

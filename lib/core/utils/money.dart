import 'package:intl/intl.dart';

/// Formatação monetária em Real brasileiro.
abstract final class Money {
  static final NumberFormat _brl =
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  static String format(double value) => _brl.format(value);

  /// Converte texto digitado pelo usuário ("1.234,56" ou "1234.56") em double.
  static double? parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d,.-]'), '');
    if (cleaned.isEmpty) return null;
    // Se houver vírgula, assume formato pt_BR: ponto = milhar, vírgula = decimal.
    final normalized = cleaned.contains(',')
        ? cleaned.replaceAll('.', '').replaceAll(',', '.')
        : cleaned;
    return double.tryParse(normalized);
  }
}

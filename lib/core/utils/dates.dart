import 'package:intl/intl.dart';

/// Formatação de datas em pt_BR.
abstract final class Dates {
  static final DateFormat _short = DateFormat('dd/MM/yyyy');
  static final DateFormat _withTime = DateFormat('dd/MM HH:mm');

  static String short(DateTime d) => _short.format(d);
  static String withTime(DateTime d) => _withTime.format(d);

  /// Só a parte de data (meia-noite local).
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

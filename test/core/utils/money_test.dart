import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/utils/money.dart';

void main() {
  group('Money.parse', () {
    test('formato brasileiro', () {
      expect(Money.parse('1.234,56'), 1234.56);
      expect(Money.parse('R\$ 99,90'), 99.90);
      expect(Money.parse('0,5'), 0.5);
    });

    test('formato com ponto decimal', () {
      expect(Money.parse('1234.56'), 1234.56);
      expect(Money.parse('100'), 100);
    });

    test('entrada inválida', () {
      expect(Money.parse(''), isNull);
      expect(Money.parse('abc'), isNull);
    });
  });

  test('Money.format usa R\$ e vírgula decimal', () {
    final out = Money.format(1234.5);
    expect(out, contains('R\$'));
    expect(out, contains('1.234,50'));
  });

  group('Money.compact', () {
    test('milhares e milhoes abreviados', () {
      expect(Money.compact(12500), 'R\$ 12,5 mil');
      expect(Money.compact(1000), 'R\$ 1 mil');
      expect(Money.compact(1200000), 'R\$ 1,2 mi');
    });

    test('abaixo de mil usa o formato completo', () {
      expect(Money.compact(999), contains('999,00'));
      expect(Money.compact(0), contains('0,00'));
    });
  });
}

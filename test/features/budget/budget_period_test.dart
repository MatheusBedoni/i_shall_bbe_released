import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/budget_period.dart';

void main() {
  const dec = BudgetPeriod(year: 2025, month: 12);

  test('key e parse são inversos', () {
    expect(dec.key, '2025-12');
    expect(BudgetPeriod.parse('2025-12'), dec);
    expect(BudgetPeriod.parse('2026-01').key, '2026-01');
  });

  test('previous/next atravessam o ano', () {
    expect(dec.next, const BudgetPeriod(year: 2026, month: 1));
    expect(const BudgetPeriod(year: 2026, month: 1).previous, dec);
  });

  test('daysInMonth considera ano bissexto', () {
    expect(const BudgetPeriod(year: 2024, month: 2).daysInMonth, 29);
    expect(const BudgetPeriod(year: 2025, month: 2).daysInMonth, 28);
    expect(dec.daysInMonth, 31);
  });

  test('daysRemaining: mês atual inclui hoje', () {
    expect(dec.daysRemaining(DateTime(2025, 12, 12)), 20);
    expect(dec.daysRemaining(DateTime(2025, 12, 31)), 1);
  });

  test('daysRemaining: mês futuro = todos os dias, passado = zero', () {
    expect(dec.daysRemaining(DateTime(2025, 11, 15)), 31);
    expect(dec.daysRemaining(DateTime(2026, 1, 1)), 0);
  });

  test('label em português', () {
    expect(dec.label, 'Dezembro 2025');
  });
}

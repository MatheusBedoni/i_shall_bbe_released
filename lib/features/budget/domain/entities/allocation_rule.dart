import '../../../../core/error/failures.dart';

/// Regra de distribuição do ganho mensal, em **cascata dinâmica**:
///
/// 1. Despesas fixas: `ganho × fixedExpensePct`.
/// 2. Investimentos: `(ganho − fixas gastas) × investmentPct`.
/// 3. Despesas recorrentes: `ganho − fixas gastas − investimentos feitos`.
///
/// Como cada etapa usa o valor **realmente gasto** na anterior, o que não foi
/// usado em fixas ou investimentos é realocado automaticamente para as
/// recorrentes, mês a mês.
final class AllocationRule {
  const AllocationRule({
    required this.fixedExpensePct,
    required this.investmentPct,
  });

  /// Padrão: 33% do ganho para fixas; 33% do que sobrar para investimentos.
  static const defaultRule =
      AllocationRule(fixedExpensePct: 0.33, investmentPct: 0.33);

  /// Fração (0..1) do ganho destinada a despesas fixas.
  final double fixedExpensePct;

  /// Fração (0..1) do que sobra após as fixas destinada a investimentos.
  final double investmentPct;

  /// Fração **nominal** do ganho que sobra para recorrentes quando fixas e
  /// investimentos gastam exatamente o orçamento. Só para exibição.
  double get nominalRecurringPct =>
      ((1 - fixedExpensePct) * (1 - investmentPct)).clamp(0, 1).toDouble();

  /// Fração nominal do ganho destinada a investimentos (exibição).
  double get nominalInvestmentPct =>
      ((1 - fixedExpensePct) * investmentPct).clamp(0, 1).toDouble();

  Failure? validate() {
    if (fixedExpensePct < 0 || fixedExpensePct > 1) {
      return const ValidationFailure(
        'O percentual de despesas fixas deve estar entre 0% e 100%.',
      );
    }
    if (investmentPct < 0 || investmentPct > 1) {
      return const ValidationFailure(
        'O percentual de investimentos deve estar entre 0% e 100%.',
      );
    }
    return null;
  }

  AllocationRule copyWith({double? fixedExpensePct, double? investmentPct}) =>
      AllocationRule(
        fixedExpensePct: fixedExpensePct ?? this.fixedExpensePct,
        investmentPct: investmentPct ?? this.investmentPct,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllocationRule &&
          other.fixedExpensePct == fixedExpensePct &&
          other.investmentPct == investmentPct;

  @override
  int get hashCode => Object.hash(fixedExpensePct, investmentPct);
}

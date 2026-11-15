import '../../../../core/error/failures.dart';

/// Regra de distribuição do ganho mensal entre os envelopes.
///
/// Despesas fixas e investimentos recebem um percentual do ganho; o que sobra
/// é o envelope de despesas recorrentes (modelo em cascata, como no protótipo:
/// "após despesas fixas" / "após investimentos").
final class AllocationRule {
  const AllocationRule({
    required this.fixedExpensePct,
    required this.investmentPct,
  });

  /// Padrão: 33% fixas, 33% investimentos, 34% recorrentes.
  static const defaultRule =
      AllocationRule(fixedExpensePct: 0.33, investmentPct: 0.33);

  /// Fração (0..1) do ganho destinada a despesas fixas.
  final double fixedExpensePct;

  /// Fração (0..1) do ganho destinada a investimentos.
  final double investmentPct;

  /// Fração residual destinada a despesas recorrentes.
  double get recurringExpensePct =>
      (1 - fixedExpensePct - investmentPct).clamp(0, 1).toDouble();

  Failure? validate() {
    if (fixedExpensePct < 0 || investmentPct < 0) {
      return const ValidationFailure('Percentuais não podem ser negativos.');
    }
    if (fixedExpensePct + investmentPct > 1.0 + 1e-9) {
      return const ValidationFailure(
        'A soma de despesas fixas e investimentos não pode passar de 100%.',
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

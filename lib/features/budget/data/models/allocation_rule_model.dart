import '../../domain/entities/allocation_rule.dart';

abstract final class AllocationRuleModel {
  static const fieldFixed = 'fixedExpensePct';
  static const fieldInvestment = 'investmentPct';

  static AllocationRule fromMap(Map<String, dynamic>? data) {
    if (data == null) return AllocationRule.defaultRule;
    return AllocationRule(
      fixedExpensePct: (data[fieldFixed] as num?)?.toDouble() ??
          AllocationRule.defaultRule.fixedExpensePct,
      investmentPct: (data[fieldInvestment] as num?)?.toDouble() ??
          AllocationRule.defaultRule.investmentPct,
    );
  }

  static Map<String, dynamic> toMap(AllocationRule rule) => {
        fieldFixed: rule.fixedExpensePct,
        fieldInvestment: rule.investmentPct,
      };
}

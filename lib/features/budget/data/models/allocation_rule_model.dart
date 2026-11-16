import '../../../../core/data/sync/doc_record.dart';
import '../../domain/entities/allocation_rule.dart';

abstract final class AllocationRuleModel {
  /// Id fixo do documento em `settings`.
  static const docId = 'allocation_rule';

  static const fieldFixed = 'fixedExpensePct';
  static const fieldInvestment = 'investmentPct';

  static AllocationRule fromMap(DocData? data) {
    if (data == null) return AllocationRule.defaultRule;
    return AllocationRule(
      fixedExpensePct: (data[fieldFixed] as num?)?.toDouble() ??
          AllocationRule.defaultRule.fixedExpensePct,
      investmentPct: (data[fieldInvestment] as num?)?.toDouble() ??
          AllocationRule.defaultRule.investmentPct,
    );
  }

  static DocData toMap(AllocationRule rule) => {
        fieldFixed: rule.fixedExpensePct,
        fieldInvestment: rule.investmentPct,
      };
}

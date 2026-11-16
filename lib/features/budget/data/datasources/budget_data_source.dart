import '../../domain/entities/allocation_rule.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_period.dart';

/// Fonte de dados do orçamento. A implementação padrão é local
/// (`LocalBudgetDataSource`), sincronizada com o Firestore pelo `SyncEngine`.
abstract interface class BudgetDataSource {
  Stream<List<BudgetEntry>> watchEntries(BudgetPeriod period);
  Future<BudgetEntry> addEntry(BudgetEntry entry);
  Future<void> updateEntry(BudgetEntry entry);
  Future<void> deleteEntry(String id);
  Future<int> copyEntries(BudgetPeriod from, BudgetPeriod to);
  Stream<AllocationRule> watchAllocationRule();
  Future<void> saveAllocationRule(AllocationRule rule);
}

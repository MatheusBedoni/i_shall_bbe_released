import '../../../../core/data/repository_guard.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/allocation_rule.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_period.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/budget_data_source.dart';

final class BudgetRepositoryImpl with RepositoryGuard implements BudgetRepository {
  const BudgetRepositoryImpl(this._ds);
  final BudgetDataSource _ds;

  @override
  Stream<Result<List<BudgetEntry>>> watchEntries(BudgetPeriod period) =>
      wrapStream(() => _ds.watchEntries(period));

  @override
  Future<Result<BudgetEntry>> addEntry(BudgetEntry entry) =>
      guard(() => _ds.addEntry(entry));

  @override
  Future<Result<void>> updateEntry(BudgetEntry entry) =>
      guard(() => _ds.updateEntry(entry));

  @override
  Future<Result<void>> deleteEntry(String entryId) =>
      guard(() => _ds.deleteEntry(entryId));

  @override
  Future<Result<int>> copyEntries({
    required BudgetPeriod from,
    required BudgetPeriod to,
  }) =>
      guard(() => _ds.copyEntries(from, to));

  @override
  Stream<Result<AllocationRule>> watchAllocationRule() =>
      wrapStream(_ds.watchAllocationRule);

  @override
  Future<Result<void>> saveAllocationRule(AllocationRule rule) =>
      guard(() => _ds.saveAllocationRule(rule));
}

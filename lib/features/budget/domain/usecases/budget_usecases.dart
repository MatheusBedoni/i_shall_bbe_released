import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/allocation_rule.dart';
import '../entities/budget_entry.dart';
import '../entities/budget_period.dart';
import '../repositories/budget_repository.dart';

export 'compute_budget_summary.dart';

final class WatchEntries {
  const WatchEntries(this._repo);
  final BudgetRepository _repo;

  Stream<Result<List<BudgetEntry>>> call(BudgetPeriod period) =>
      _repo.watchEntries(period);
}

final class AddEntry implements UseCase<BudgetEntry, BudgetEntry> {
  const AddEntry(this._repo);
  final BudgetRepository _repo;

  @override
  Future<Result<BudgetEntry>> call(BudgetEntry entry) async {
    final invalid = _validate(entry);
    if (invalid != null) return Error(invalid);
    return _repo.addEntry(entry);
  }
}

final class UpdateEntry implements UseCase<void, BudgetEntry> {
  const UpdateEntry(this._repo);
  final BudgetRepository _repo;

  @override
  Future<Result<void>> call(BudgetEntry entry) async {
    final invalid = _validate(entry);
    if (invalid != null) return Error(invalid);
    return _repo.updateEntry(entry);
  }
}

final class DeleteEntry implements UseCase<void, String> {
  const DeleteEntry(this._repo);
  final BudgetRepository _repo;

  @override
  Future<Result<void>> call(String entryId) => _repo.deleteEntry(entryId);
}

final class CopyEntriesParams {
  const CopyEntriesParams({required this.from, required this.to});
  final BudgetPeriod from;
  final BudgetPeriod to;
}

/// Copia os lançamentos de um mês para outro (ex.: repetir o mês anterior).
final class CopyEntries implements UseCase<int, CopyEntriesParams> {
  const CopyEntries(this._repo);
  final BudgetRepository _repo;

  @override
  Future<Result<int>> call(CopyEntriesParams params) {
    if (params.from == params.to) {
      return Future.value(
        const Error(ValidationFailure('Os períodos devem ser diferentes.')),
      );
    }
    return _repo.copyEntries(from: params.from, to: params.to);
  }
}

final class WatchAllocationRule {
  const WatchAllocationRule(this._repo);
  final BudgetRepository _repo;

  Stream<Result<AllocationRule>> call() => _repo.watchAllocationRule();
}

final class SaveAllocationRule implements UseCase<void, AllocationRule> {
  const SaveAllocationRule(this._repo);
  final BudgetRepository _repo;

  @override
  Future<Result<void>> call(AllocationRule rule) async {
    final invalid = rule.validate();
    if (invalid != null) return Error(invalid);
    return _repo.saveAllocationRule(rule);
  }
}

Failure? _validate(BudgetEntry entry) {
  if (entry.description.trim().isEmpty) {
    return const ValidationFailure('Informe uma descrição.');
  }
  if (entry.amount <= 0 || entry.amount.isNaN || entry.amount.isInfinite) {
    return const ValidationFailure('O valor deve ser maior que zero.');
  }
  return null;
}

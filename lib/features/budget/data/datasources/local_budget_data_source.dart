import 'package:sembast/sembast.dart';

import '../../../../core/data/local/local_database.dart';
import '../../../../core/data/sync/doc_record.dart';
import '../../../../core/data/sync/synced_collection.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/allocation_rule.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_period.dart';
import '../models/allocation_rule_model.dart';
import '../models/budget_entry_model.dart';
import 'budget_data_source.dart';

/// Orçamento no banco local, espelhado em:
/// ```
/// users/{uid}/budget_entries/{id}
/// users/{uid}/settings/allocation_rule
/// ```
final class LocalBudgetDataSource implements BudgetDataSource {
  LocalBudgetDataSource(
    LocalDatabase local, {
    DateTime Function()? clock,
    String Function()? newId,
  })  : _entries = SyncedCollection(
          local,
          SyncCollections.budgetEntries,
          clock: clock,
        ),
        _settings = SyncedCollection(
          local,
          SyncCollections.settings,
          clock: clock,
        ),
        _clock = clock ?? DateTime.now,
        _newId = newId ?? newDocId;

  final SyncedCollection _entries;
  final SyncedCollection _settings;
  final DateTime Function() _clock;
  final String Function() _newId;

  static Finder _periodFinder(BudgetPeriod period) => Finder(
        filter: Filter.equals(BudgetEntryModel.fieldPeriod, period.key),
        sortOrders: [SortOrder(BudgetEntryModel.fieldCreatedAt)],
      );

  @override
  Stream<List<BudgetEntry>> watchEntries(BudgetPeriod period) => _entries
      .watch(finder: _periodFinder(period))
      .map((docs) => docs.map(BudgetEntryModel.fromRecord).toList());

  @override
  Future<BudgetEntry> addEntry(BudgetEntry entry) async {
    final saved = entry.copyWith(id: _newId());
    await _entries.put(saved.id, BudgetEntryModel.toMap(saved));
    return saved;
  }

  @override
  Future<void> updateEntry(BudgetEntry entry) =>
      _entries.put(entry.id, BudgetEntryModel.toMap(entry));

  @override
  Future<void> deleteEntry(String id) => _entries.delete(id);

  @override
  Future<int> copyEntries(BudgetPeriod from, BudgetPeriod to) =>
      _entries.transaction((txn) async {
        final source =
            await _entries.find(finder: _periodFinder(from), client: txn);
        final now = _clock();
        for (final doc in source) {
          final copy = BudgetEntryModel.fromRecord(doc).copyWith(
            id: _newId(),
            period: to,
            createdAt: now,
          );
          await _entries.put(copy.id, BudgetEntryModel.toMap(copy), txn: txn);
        }
        return source.length;
      });

  @override
  Stream<AllocationRule> watchAllocationRule() => _settings
      .watchDoc(AllocationRuleModel.docId)
      .map((doc) => AllocationRuleModel.fromMap(doc?.data));

  @override
  Future<void> saveAllocationRule(AllocationRule rule) =>
      _settings.put(AllocationRuleModel.docId, AllocationRuleModel.toMap(rule));
}

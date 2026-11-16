import 'package:sembast/sembast.dart';

import '../../../../core/data/local/local_database.dart';
import '../../../../core/data/sync/doc_record.dart';
import '../../../../core/data/sync/synced_collection.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/goal.dart';
import '../models/goal_model.dart';
import 'goal_data_source.dart';

/// Metas no banco local, espelhadas em `users/{uid}/goals/{id}`.
final class LocalGoalDataSource implements GoalDataSource {
  LocalGoalDataSource(
    LocalDatabase local, {
    DateTime Function()? clock,
    String Function()? newId,
  })  : _goals = SyncedCollection(local, SyncCollections.goals, clock: clock),
        _newId = newId ?? newDocId;

  final SyncedCollection _goals;
  final String Function() _newId;

  @override
  Stream<List<Goal>> watchGoals() => _goals
      .watch(finder: Finder(sortOrders: [SortOrder(GoalModel.fieldName)]))
      .map((docs) => docs.map(GoalModel.fromRecord).toList());

  @override
  Future<Goal> addGoal(Goal goal) async {
    final saved = goal.copyWith(id: _newId());
    await _goals.put(saved.id, GoalModel.toMap(saved));
    return saved;
  }

  @override
  Future<void> updateGoal(Goal goal) =>
      _goals.put(goal.id, GoalModel.toMap(goal));

  @override
  Future<void> deleteGoal(String goalId) => _goals.delete(goalId);
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/allocation_rule.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_period.dart';
import '../models/allocation_rule_model.dart';
import '../models/budget_entry_model.dart';

abstract interface class BudgetRemoteDataSource {
  Stream<List<BudgetEntry>> watchEntries(BudgetPeriod period);
  Future<BudgetEntry> addEntry(BudgetEntry entry);
  Future<void> updateEntry(BudgetEntry entry);
  Future<void> deleteEntry(String id);
  Future<int> copyEntries(BudgetPeriod from, BudgetPeriod to);
  Stream<AllocationRule> watchAllocationRule();
  Future<void> saveAllocationRule(AllocationRule rule);
}

/// Estrutura no Firestore:
/// ```
/// users/{uid}/budget_entries/{id}
/// users/{uid}/settings/allocation_rule
/// ```
final class FirestoreBudgetDataSource implements BudgetRemoteDataSource {
  const FirestoreBudgetDataSource({
    required this._db,
    required this._currentUid,
  });

  final FirebaseFirestore _db;
  final String? Function() _currentUid;

  String get _uid {
    final uid = _currentUid();
    if (uid == null) throw const AuthException('Usuário não autenticado.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _entries =>
      _db.collection('users').doc(_uid).collection('budget_entries');

  DocumentReference<Map<String, dynamic>> get _ruleDoc =>
      _db.collection('users').doc(_uid).collection('settings').doc('allocation_rule');

  @override
  Stream<List<BudgetEntry>> watchEntries(BudgetPeriod period) => _entries
      .where(BudgetEntryModel.fieldPeriod, isEqualTo: period.key)
      .orderBy(BudgetEntryModel.fieldCreatedAt)
      .snapshots()
      .map((snap) => snap.docs.map(BudgetEntryModel.fromDoc).toList())
      .handleError(_rethrow);

  @override
  Future<BudgetEntry> addEntry(BudgetEntry entry) => _guard(() async {
        final ref = await _entries.add(BudgetEntryModel.toMap(entry));
        return entry.copyWith(id: ref.id);
      });

  @override
  Future<void> updateEntry(BudgetEntry entry) => _guard(
        () => _entries.doc(entry.id).update(BudgetEntryModel.toMap(entry)),
      );

  @override
  Future<void> deleteEntry(String id) => _guard(() => _entries.doc(id).delete());

  @override
  Future<int> copyEntries(BudgetPeriod from, BudgetPeriod to) => _guard(() async {
        final source = await _entries
            .where(BudgetEntryModel.fieldPeriod, isEqualTo: from.key)
            .get();
        if (source.docs.isEmpty) return 0;
        final batch = _db.batch();
        final now = DateTime.now();
        for (final doc in source.docs) {
          final entry = BudgetEntryModel.fromDoc(doc).copyWith(
            period: to,
            createdAt: now,
          );
          batch.set(_entries.doc(), BudgetEntryModel.toMap(entry));
        }
        await batch.commit();
        return source.docs.length;
      });

  @override
  Stream<AllocationRule> watchAllocationRule() => _ruleDoc
      .snapshots()
      .map((snap) => AllocationRuleModel.fromMap(snap.data()))
      .handleError(_rethrow);

  @override
  Future<void> saveAllocationRule(AllocationRule rule) => _guard(
        () => _ruleDoc.set(AllocationRuleModel.toMap(rule), SetOptions(merge: true)),
      );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _translate(e);
    }
  }

  static Never _rethrow(Object error) {
    if (error is FirebaseException) throw _translate(error);
    throw error;
  }

  static Exception _translate(FirebaseException e) => switch (e.code) {
        'permission-denied' => const AuthException('Sem permissão para acessar os dados.'),
        'unavailable' => const NetworkException(),
        _ => ServerException(e.message ?? e.code),
      };
}

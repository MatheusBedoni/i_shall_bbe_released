import 'dart:async';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/allocation_rule.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_period.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/budget_remote_data_source.dart';

final class BudgetRepositoryImpl implements BudgetRepository {
  const BudgetRepositoryImpl(this._remote);
  final BudgetRemoteDataSource _remote;

  @override
  Stream<Result<List<BudgetEntry>>> watchEntries(BudgetPeriod period) =>
      _wrapStream(() => _remote.watchEntries(period));

  @override
  Future<Result<BudgetEntry>> addEntry(BudgetEntry entry) =>
      _guard(() => _remote.addEntry(entry));

  @override
  Future<Result<void>> updateEntry(BudgetEntry entry) =>
      _guard(() => _remote.updateEntry(entry));

  @override
  Future<Result<void>> deleteEntry(String entryId) =>
      _guard(() => _remote.deleteEntry(entryId));

  @override
  Future<Result<int>> copyEntries({
    required BudgetPeriod from,
    required BudgetPeriod to,
  }) =>
      _guard(() => _remote.copyEntries(from, to));

  @override
  Stream<Result<AllocationRule>> watchAllocationRule() =>
      _wrapStream(_remote.watchAllocationRule);

  @override
  Future<Result<void>> saveAllocationRule(AllocationRule rule) =>
      _guard(() => _remote.saveAllocationRule(rule));

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Object catch (e) {
      return Error(toFailure(e));
    }
  }

  Stream<Result<T>> _wrapStream<T>(Stream<T> Function() source) {
    late StreamController<Result<T>> controller;
    StreamSubscription<T>? sub;
    controller = StreamController<Result<T>>(
      onListen: () {
        try {
          sub = source().listen(
            (value) => controller.add(Success(value)),
            onError: (Object e) => controller.add(Error(toFailure(e))),
            onDone: controller.close,
          );
        } on Object catch (e) {
          controller
            ..add(Error(toFailure(e)))
            ..close();
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// Mapeia exceções da camada data em falhas de domínio.
  static Failure toFailure(Object error) => switch (error) {
        AuthException(:final message) => AuthFailure(message),
        NetworkException(:final message) => NetworkFailure(message),
        ServerException(:final message) => ServerFailure(message),
        CacheException(:final message) => CacheFailure(message),
        _ => const UnexpectedFailure(),
      };
}

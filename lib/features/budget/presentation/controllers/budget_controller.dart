import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../portfolio/domain/entities/contribution.dart';
import '../../../portfolio/domain/usecases/portfolio_usecases.dart';
import '../../domain/entities/allocation_rule.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_period.dart';
import '../../domain/entities/budget_summary.dart';
import '../../domain/entities/entry_type.dart';
import '../../domain/usecases/budget_usecases.dart';

/// Estado da tela de orçamento mensal.
///
/// Além dos lançamentos do mês, observa os **aportes da carteira**
/// ([WatchContributions]) e soma os que caem no período ao envelope de
/// investimentos. As mutações de aportes ficam no `PortfolioController`.
final class BudgetController extends ChangeNotifier {
  BudgetController({
    required this.watchEntries,
    required this.watchAllocationRule,
    required this.watchContributions,
    required this.addEntry,
    required this.updateEntry,
    required this.deleteEntry,
    required this.copyEntries,
    required this.saveAllocationRule,
    required this.computeSummary,
    BudgetPeriod? initialPeriod,
    DateTime Function()? clock,
  })  : _period = initialPeriod ?? BudgetPeriod.now(),
        _clock = clock ?? DateTime.now;

  final WatchEntries watchEntries;
  final WatchAllocationRule watchAllocationRule;
  final WatchContributions watchContributions;
  final AddEntry addEntry;
  final UpdateEntry updateEntry;
  final DeleteEntry deleteEntry;
  final CopyEntries copyEntries;
  final SaveAllocationRule saveAllocationRule;
  final ComputeBudgetSummary computeSummary;

  final DateTime Function() _clock;

  BudgetPeriod _period;
  List<BudgetEntry> _entries = const [];
  List<Contribution> _allContributions = const [];
  AllocationRule _rule = AllocationRule.defaultRule;
  BudgetSummary? _summary;
  bool _loadingEntries = true;
  String? _error;
  String? _message;

  StreamSubscription<Object>? _entriesSub;
  StreamSubscription<Object>? _ruleSub;
  StreamSubscription<Object>? _contributionsSub;

  BudgetPeriod get period => _period;
  List<BudgetEntry> get entries => _entries;
  AllocationRule get rule => _rule;
  BudgetSummary? get summary => _summary;
  bool get loading => _loadingEntries;
  String? get error => _error;

  /// Aportes da carteira feitos dentro do período selecionado.
  List<Contribution> get contributions =>
      _allContributions.where((c) => _period.contains(c.date)).toList();

  double get linkedInvestments =>
      contributions.fold(0.0, (s, c) => s + c.amount);

  /// Mensagem transitória (ex.: "12 lançamentos copiados"). Zerada após leitura.
  String? consumeMessage() {
    final m = _message;
    _message = null;
    return m;
  }

  List<BudgetEntry> entriesOf(EntryType type) =>
      _entries.where((e) => e.type == type).toList();

  void start() {
    _ruleSub ??= watchAllocationRule().listen((result) {
      result.fold((f) => _setError(f.message), (rule) {
        _rule = rule;
        _recompute();
      });
    });
    _contributionsSub ??= watchContributions().listen((result) {
      result.fold((f) => _setError(f.message), (list) {
        _allContributions = list;
        _recompute();
      });
    });
    _subscribeEntries();
  }

  void selectPeriod(BudgetPeriod period) {
    if (period == _period) return;
    _period = period;
    _subscribeEntries();
  }

  void previousMonth() => selectPeriod(_period.previous);
  void nextMonth() => selectPeriod(_period.next);
  void goToCurrentMonth() => selectPeriod(BudgetPeriod.fromDate(_clock()));

  /// Data sugerida para um aporte lançado a partir deste mês: hoje, se o
  /// mês for o atual; senão, o primeiro dia do período.
  DateTime suggestedContributionDate() {
    final now = _clock();
    return _period.contains(now) ? now : _period.firstDay;
  }

  Future<bool> add({
    required EntryType type,
    required String description,
    required double amount,
  }) =>
      _mutate(() => addEntry(BudgetEntry(
            id: '',
            period: _period,
            type: type,
            description: description,
            amount: amount,
            createdAt: _clock(),
          )));

  Future<bool> update(BudgetEntry entry) => _mutate(() => updateEntry(entry));

  Future<bool> remove(String id) => _mutate(() => deleteEntry(id));

  Future<bool> copyFromPreviousMonth() async {
    final ok = await _mutate(
      () => copyEntries(CopyEntriesParams(from: _period.previous, to: _period)),
      onSuccess: (count) => _message = count == 0
          ? 'O mês anterior não tem lançamentos.'
          : '$count lançamento(s) copiado(s) de ${_period.previous.label}.',
    );
    return ok;
  }

  Future<bool> saveRule(AllocationRule rule) => _mutate(() => saveAllocationRule(rule));

  void _subscribeEntries() {
    _entriesSub?.cancel();
    _loadingEntries = true;
    _error = null;
    notifyListeners();
    _entriesSub = watchEntries(_period).listen((result) {
      _loadingEntries = false;
      result.fold((f) => _setError(f.message), (entries) {
        _entries = entries;
        _error = null;
        _recompute();
      });
    });
  }

  void _recompute() {
    final result = computeSummary(ComputeBudgetSummaryParams(
      period: _period,
      entries: _entries,
      rule: _rule,
      now: _clock(),
      linkedInvestments: linkedInvestments,
    ));
    result.fold((f) => _setError(f.message), (s) => _summary = s);
    notifyListeners();
  }

  Future<bool> _mutate<T>(
    Future<dynamic> Function() action, {
    void Function(T value)? onSuccess,
  }) async {
    final result = await action();
    return result.fold<bool>(
      (failure) {
        _setError(failure.message);
        return false;
      },
      (value) {
        onSuccess?.call(value as T);
        notifyListeners();
        return true;
      },
    );
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    _ruleSub?.cancel();
    _contributionsSub?.cancel();
    super.dispose();
  }
}

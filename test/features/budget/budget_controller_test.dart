import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/core/utils/result.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/allocation_rule.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/budget_entry.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/budget_period.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/entry_type.dart';
import 'package:i_shall_be_released/features/budget/domain/repositories/budget_repository.dart';
import 'package:i_shall_be_released/features/budget/domain/usecases/budget_usecases.dart';
import 'package:i_shall_be_released/features/budget/presentation/controllers/budget_controller.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset_transaction.dart';
import 'package:i_shall_be_released/features/portfolio/domain/usecases/portfolio_usecases.dart';

import '../portfolio/fakes/in_memory_portfolio_repository.dart';

/// Repositório em memória que imita o comportamento reativo do Firestore.
class InMemoryBudgetRepository implements BudgetRepository {
  final _entries = <BudgetEntry>[];
  final _entriesCtrl = StreamController<Result<List<BudgetEntry>>>.broadcast();
  final _ruleCtrl = StreamController<Result<AllocationRule>>.broadcast();
  AllocationRule _rule = AllocationRule.defaultRule;
  int _seq = 0;
  BudgetPeriod? _watched;

  void _emit() {
    final p = _watched;
    if (p == null) return;
    _entriesCtrl.add(Success(_entries.where((e) => e.period == p).toList()));
  }

  @override
  Stream<Result<List<BudgetEntry>>> watchEntries(BudgetPeriod period) {
    _watched = period;
    scheduleMicrotask(_emit);
    return _entriesCtrl.stream;
  }

  @override
  Future<Result<BudgetEntry>> addEntry(BudgetEntry entry) async {
    final saved = entry.copyWith(id: 'e${_seq++}');
    _entries.add(saved);
    _emit();
    return Success(saved);
  }

  @override
  Future<Result<void>> updateEntry(BudgetEntry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i < 0) return const Error(ServerFailure('não encontrado'));
    _entries[i] = entry;
    _emit();
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteEntry(String entryId) async {
    _entries.removeWhere((e) => e.id == entryId);
    _emit();
    return const Success(null);
  }

  @override
  Future<Result<int>> copyEntries({
    required BudgetPeriod from,
    required BudgetPeriod to,
  }) async {
    final src = _entries.where((e) => e.period == from).toList();
    for (final e in src) {
      _entries.add(e.copyWith(id: 'e${_seq++}', period: to));
    }
    _emit();
    return Success(src.length);
  }

  @override
  Stream<Result<AllocationRule>> watchAllocationRule() {
    scheduleMicrotask(() => _ruleCtrl.add(Success(_rule)));
    return _ruleCtrl.stream;
  }

  @override
  Future<Result<void>> saveAllocationRule(AllocationRule rule) async {
    _rule = rule;
    _ruleCtrl.add(Success(rule));
    return const Success(null);
  }
}

BudgetController _controller(
  BudgetRepository repo,
  InMemoryPortfolioRepository portfolio, {
  BudgetPeriod? period,
}) =>
    BudgetController(
      watchEntries: WatchEntries(repo),
      watchAllocationRule: WatchAllocationRule(repo),
      watchContributions: WatchContributions(portfolio),
      addEntry: AddEntry(repo),
      updateEntry: UpdateEntry(repo),
      deleteEntry: DeleteEntry(repo),
      copyEntries: CopyEntries(repo),
      saveAllocationRule: SaveAllocationRule(repo),
      computeSummary: const ComputeBudgetSummary(),
      initialPeriod: period ?? const BudgetPeriod(year: 2025, month: 12),
      clock: () => DateTime(2025, 12, 12),
    );

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late InMemoryBudgetRepository repo;
  late InMemoryPortfolioRepository portfolio;
  late BudgetController c;

  setUp(() {
    repo = InMemoryBudgetRepository();
    portfolio = InMemoryPortfolioRepository();
    c = _controller(repo, portfolio);
    c.start();
  });

  tearDown(() => c.dispose());

  test('carrega lista vazia e calcula resumo zerado', () async {
    await _flush();
    expect(c.loading, isFalse);
    expect(c.entries, isEmpty);
    expect(c.summary?.income, 0);
  });

  test('adicionar lançamento atualiza entradas e resumo', () async {
    await _flush();
    final ok = await c.add(
      type: EntryType.income,
      description: 'Salário',
      amount: 5000,
    );
    await _flush();
    expect(ok, isTrue);
    expect(c.entriesOf(EntryType.income), hasLength(1));
    expect(c.summary?.income, 5000);
    expect(c.summary?.fixedExpenses.budget, closeTo(1650, 1e-9));
    // Nada gasto em fixas ainda → investimentos sobre o ganho inteiro.
    expect(c.summary?.investments.budget, closeTo(1650, 1e-9));
    expect(c.summary?.recurringExpenses.budget, closeTo(5000, 1e-9));
  });

  test('validação impede valor zero e expõe erro', () async {
    await _flush();
    final ok = await c.add(
      type: EntryType.fixedExpense,
      description: 'Aluguel',
      amount: 0,
    );
    expect(ok, isFalse);
    expect(c.error, 'O valor deve ser maior que zero.');
    expect(c.entries, isEmpty);
  });

  test('trocar período filtra lançamentos', () async {
    await _flush();
    await c.add(type: EntryType.income, description: 'Dez', amount: 100);
    await _flush();
    c.nextMonth();
    await _flush();
    expect(c.period, const BudgetPeriod(year: 2026, month: 1));
    expect(c.entries, isEmpty);
    c.previousMonth();
    await _flush();
    expect(c.entries, hasLength(1));
  });

  test('copiar mês anterior traz os lançamentos e gera mensagem', () async {
    await _flush();
    await c.add(type: EntryType.fixedExpense, description: 'Aluguel', amount: 1500);
    await _flush();
    c.nextMonth();
    await _flush();
    final ok = await c.copyFromPreviousMonth();
    await _flush();
    expect(ok, isTrue);
    expect(c.entries, hasLength(1));
    expect(c.entries.first.period, const BudgetPeriod(year: 2026, month: 1));
    expect(c.consumeMessage(), contains('1 lançamento(s) copiado(s)'));
    expect(c.consumeMessage(), isNull);
  });

  test('salvar regra recalcula o resumo', () async {
    await _flush();
    await c.add(type: EntryType.income, description: 'Salário', amount: 1000);
    await _flush();
    final ok = await c.saveRule(
      const AllocationRule(fixedExpensePct: 0.5, investmentPct: 0.1),
    );
    await _flush();
    expect(ok, isTrue);
    expect(c.rule.fixedExpensePct, 0.5);
    expect(c.summary?.fixedExpenses.budget, 500);
    expect(c.summary?.investments.budget, closeTo(100, 1e-9));
    expect(c.summary?.recurringExpenses.budget, closeTo(1000, 1e-9));
  });

  test('regra inválida é rejeitada', () async {
    await _flush();
    final ok = await c.saveRule(
      const AllocationRule(fixedExpensePct: 1.5, investmentPct: 0.5),
    );
    expect(ok, isFalse);
    expect(c.error, contains('100%'));
  });

  test('aportes da carteira no mês entram no envelope de investimentos', () async {
    await _flush();
    await c.add(type: EntryType.income, description: 'Salário', amount: 10000);
    await c.add(type: EntryType.investment, description: 'Poupança', amount: 200);
    final asset = (await portfolio.addAsset(const Asset(
      id: '',
      ticker: 'PETR4',
      name: 'Petrobras',
      assetClass: AssetClass.stock,
    )))
        .valueOrNull!;
    // Dentro do período (dez/2025): custo 10 × 30 + 5 = 305.
    await portfolio.addTransaction(AssetTransaction(
      id: '',
      assetId: asset.id,
      type: TransactionType.buy,
      quantity: 10,
      unitPrice: 30,
      fees: 5,
      date: DateTime(2025, 12, 3),
    ));
    // Fora do período e venda: ignorados.
    await portfolio.addTransaction(AssetTransaction(
      id: '',
      assetId: asset.id,
      type: TransactionType.buy,
      quantity: 1,
      unitPrice: 999,
      date: DateTime(2025, 11, 30),
    ));
    await portfolio.addTransaction(AssetTransaction(
      id: '',
      assetId: asset.id,
      type: TransactionType.sell,
      quantity: 1,
      unitPrice: 50,
      date: DateTime(2025, 12, 10),
    ));
    await _flush();

    expect(c.contributions.map((x) => x.amount), [305]);
    expect(c.linkedInvestments, 305);
    expect(c.summary?.investments.spent, closeTo(505, 1e-9));
    // recorrentes = 10000 − 0 fixas − 505 investidos
    expect(c.summary?.recurringExpenses.budget, closeTo(9495, 1e-9));
    expect(c.summary?.finalBalance, closeTo(9495, 1e-9));

    // Trocar de mês: o aporte de novembro aparece lá.
    c.previousMonth();
    await _flush();
    expect(c.contributions.map((x) => x.amount), [999]);
    expect(c.suggestedContributionDate(), DateTime(2025, 11, 1));
    c.nextMonth();
    await _flush();
    expect(c.suggestedContributionDate(), DateTime(2025, 12, 12));
  });
}

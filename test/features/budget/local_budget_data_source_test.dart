import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/data/local/local_database.dart';
import 'package:i_shall_be_released/core/data/sync/doc_record.dart';
import 'package:i_shall_be_released/core/data/sync/outbox.dart';
import 'package:i_shall_be_released/features/budget/data/datasources/local_budget_data_source.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/allocation_rule.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/budget_entry.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/budget_period.dart';
import 'package:i_shall_be_released/features/budget/domain/entities/entry_type.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late LocalDatabase local;
  late LocalBudgetDataSource ds;
  late Outbox outbox;
  var seq = 0;
  final jan = BudgetPeriod(year: 2026, month: 1);
  final feb = BudgetPeriod(year: 2026, month: 2);
  final now = DateTime(2026, 1, 5, 9);

  BudgetEntry entry(String desc, {BudgetPeriod? period, double amount = 10}) =>
      BudgetEntry(
        id: '',
        period: period ?? jan,
        type: EntryType.fixedExpense,
        description: desc,
        amount: amount,
        createdAt: now,
      );

  setUp(() async {
    seq = 0;
    local = LocalDatabase(
      await newDatabaseFactoryMemory().openDatabase('budget.db'),
    );
    outbox = Outbox(local);
    ds = LocalBudgetDataSource(
      local,
      clock: () => now,
      newId: () => 'id${seq++}',
    );
  });

  tearDown(() => local.close());

  test('addEntry gera id, grava localmente e enfileira o envio', () async {
    final saved = await ds.addEntry(entry('Aluguel', amount: 1500));

    expect(saved.id, 'id0');
    expect(saved.description, 'Aluguel');

    final pending = await outbox.pending(local.raw);
    expect(pending, hasLength(1));
    expect(pending.single.collection, SyncCollections.budgetEntries);
    expect(pending.single.id, 'id0');
    expect(pending.single.op, OutboxOp.set);
    expect(pending.single.data!['amount'], 1500);
    expect(pending.single.data!['createdAt'], now);
    expect(pending.single.data![SyncFields.updatedAt], now);
  });

  test('watchEntries filtra por período, ordena por createdAt e reage',
      () async {
    final stream = ds.watchEntries(jan);
    final expectation = expectLater(
      stream.map((l) => l.map((e) => e.description).toList()),
      emitsInOrder([
        <String>[],
        ['Luz'],
        ['Luz', 'Água'],
      ]),
    );

    // Entrada de outro mês não aparece.
    await ds.addEntry(entry('Fev', period: feb));
    await ds.addEntry(entry('Luz'));
    await ds.addEntry(
      entry('Água').copyWith(createdAt: now.add(const Duration(minutes: 1))),
    );

    await expectation;
  });

  test('update e delete refletem no local e na outbox (compactada)', () async {
    final saved = await ds.addEntry(entry('Luz'));
    await ds.updateEntry(saved.copyWith(amount: 99));

    var pending = await outbox.pending(local.raw);
    expect(pending, hasLength(1));
    expect(pending.single.data!['amount'], 99);

    await ds.deleteEntry(saved.id);
    pending = await outbox.pending(local.raw);
    expect(pending.single.op, OutboxOp.delete);
    expect(await ds.watchEntries(jan).first, isEmpty);
  });

  test('copyEntries duplica o mês com novos ids e createdAt', () async {
    await ds.addEntry(entry('Luz'));
    await ds.addEntry(entry('Água'));
    await ds.addEntry(entry('Fev', period: feb));

    final copied = await ds.copyEntries(jan, feb);

    expect(copied, 2);
    final febEntries = await ds.watchEntries(feb).first;
    expect(
      febEntries.map((e) => e.description),
      unorderedEquals(['Fev', 'Luz', 'Água']),
    );
    expect(febEntries.map((e) => e.id).toSet(), hasLength(3));
    expect(await outbox.count(local.raw), 5);
  });

  test('copyEntries de mês vazio não grava nada', () async {
    expect(await ds.copyEntries(jan, feb), 0);
    expect(await outbox.count(local.raw), 0);
  });

  test('regra de alocação usa o padrão até ser salva', () async {
    final expectation = expectLater(
      ds.watchAllocationRule(),
      emitsInOrder([
        AllocationRule.defaultRule,
        const AllocationRule(fixedExpensePct: 0.5, investmentPct: 0.2),
      ]),
    );

    await ds.saveAllocationRule(
      const AllocationRule(fixedExpensePct: 0.5, investmentPct: 0.2),
    );
    await expectation;

    final pending = await outbox.pending(local.raw);
    expect(pending.single.collection, SyncCollections.settings);
    expect(pending.single.id, 'allocation_rule');
  });
}

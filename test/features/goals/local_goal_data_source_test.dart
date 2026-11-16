import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/data/local/local_database.dart';
import 'package:i_shall_be_released/core/data/sync/outbox.dart';
import 'package:i_shall_be_released/features/goals/data/datasources/local_goal_data_source.dart';
import 'package:i_shall_be_released/features/goals/data/models/goal_model.dart';
import 'package:i_shall_be_released/features/goals/domain/entities/goal.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late LocalDatabase local;
  late LocalGoalDataSource ds;
  late Outbox outbox;
  var seq = 0;
  final now = DateTime(2026, 3, 1);

  setUp(() async {
    seq = 0;
    local = LocalDatabase(
      await newDatabaseFactoryMemory().openDatabase('goals.db'),
    );
    outbox = Outbox(local);
    ds = LocalGoalDataSource(local, clock: () => now, newId: () => 'id${seq++}');
  });

  tearDown(() => local.close());

  Goal goal(String name, {DateTime? deadline, List<String> linked = const []}) =>
      Goal(
        id: '',
        name: name,
        targetAmount: 10000,
        currentAmount: 250.5,
        monthlyContribution: 300,
        annualRate: 0.105,
        deadline: deadline,
        linkedAssetIds: linked,
      );

  test('metas vêm ordenadas por nome', () async {
    await ds.addGoal(goal('Viagem'));
    await ds.addGoal(goal('Aposentadoria'));
    await ds.addGoal(goal('Reserva'));

    final goals = await ds.watchGoals().first;
    expect(goals.map((g) => g.name), ['Aposentadoria', 'Reserva', 'Viagem']);
  });

  test('ida e volta preserva prazo, taxa e ativos vinculados', () async {
    final saved = await ds.addGoal(goal(
      'Reserva',
      deadline: DateTime(2027, 6, 15),
      linked: ['a1', 'a2'],
    ));
    expect(saved.id, 'id0');

    final loaded = (await ds.watchGoals().first).single;
    expect(loaded, saved);
    expect(loaded.deadline, DateTime(2027, 6, 15));
    expect(loaded.annualRate, 0.105);
    expect(loaded.linkedAssetIds, ['a1', 'a2']);
  });

  test('sem prazo e sem vínculo grava nulo e lista vazia', () async {
    await ds.addGoal(goal('Reserva'));
    final loaded = (await ds.watchGoals().first).single;
    expect(loaded.deadline, isNull);
    expect(loaded.linkedAssetIds, isEmpty);

    final pending = await outbox.pending(local.raw);
    expect(pending.single.data![GoalModel.fieldDeadline], isNull);
    expect(pending.single.data![GoalModel.fieldLinkedAssetIds], isEmpty);
  });

  test('update preserva o id e enfileira o documento inteiro', () async {
    final saved = await ds.addGoal(goal('Reserva'));
    await ds.updateGoal(saved.copyWith(linkedAssetIds: ['a9'], currentAmount: 0));

    final updated = (await ds.watchGoals().first).single;
    expect(updated.id, saved.id);
    expect(updated.linkedAssetIds, ['a9']);
    expect(updated.currentAmount, 0);

    // A outbox compacta por documento: só a versão mais recente fica na fila.
    final pending = await outbox.pending(local.raw);
    expect(pending, hasLength(1));
    expect(pending.single.data![GoalModel.fieldName], 'Reserva');
    expect(pending.single.data![GoalModel.fieldLinkedAssetIds], ['a9']);
  });

  test('delete apaga localmente e enfileira a exclusão', () async {
    final saved = await ds.addGoal(goal('Reserva'));
    await ds.deleteGoal(saved.id);

    expect(await ds.watchGoals().first, isEmpty);
    final deletes = (await outbox.pending(local.raw))
        .where((p) => p.op == OutboxOp.delete);
    expect(deletes.map((p) => p.key), ['goals/${saved.id}']);
  });

  test('modelo tolera documentos antigos sem os campos novos', () {
    final g = GoalModel.fromMap('x', {
      GoalModel.fieldName: 'Antiga',
      GoalModel.fieldTargetAmount: 100,
    });
    expect(g.name, 'Antiga');
    expect(g.targetAmount, 100);
    expect(g.currentAmount, 0);
    expect(g.deadline, isNull);
    expect(g.linkedAssetIds, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/data/local/local_database.dart';
import 'package:i_shall_be_released/core/data/sync/doc_record.dart';
import 'package:i_shall_be_released/core/data/sync/outbox.dart';
import 'package:i_shall_be_released/core/data/sync/sync_engine.dart';
import 'package:i_shall_be_released/core/data/sync/sync_status.dart';
import 'package:i_shall_be_released/core/data/sync/synced_collection.dart';
import 'package:i_shall_be_released/core/error/exceptions.dart';
import 'package:sembast/sembast_memory.dart';

import '../fakes/fake_remote_store.dart';

const col = 'budget_entries';

void main() {
  late LocalDatabase local;
  late FakeRemoteStore remote;
  late SyncEngine engine;
  late SyncedCollection entries;
  late DateTime now;

  /// Espera o loop de eventos esvaziar (streams, transações, microtasks).
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    now = DateTime(2026, 1, 10, 12);
    local = LocalDatabase(
      await newDatabaseFactoryMemory().openDatabase('test.db'),
    );
    remote = FakeRemoteStore();
    entries = SyncedCollection(local, col, clock: () => now);
    engine = SyncEngine(
      local: local,
      remote: remote,
      collections: const [col],
      pushTimeout: const Duration(milliseconds: 50),
      // Nunca dispara sozinho nos testes: a retomada é explícita via syncNow.
      retryDelay: (_) => const Duration(hours: 1),
      clock: () => now,
    );
  });

  tearDown(() async {
    await engine.dispose();
    await remote.dispose();
    await local.close();
  });

  Future<List<DocRecord>> localDocs() => entries.find();

  group('pull', () {
    test('espelha os documentos remotos no banco local', () async {
      remote.docs[col] = {
        'a': {'description': 'Aluguel', 'updatedAt': now},
        'b': {'description': 'Luz', 'updatedAt': now},
      };

      await engine.start();
      await settle();

      final docs = await localDocs();
      expect(docs.map((d) => d.id), unorderedEquals(['a', 'b']));
      expect(docs.firstWhere((d) => d.id == 'a').data['description'], 'Aluguel');
      expect(engine.status.pending, 0);
    });

    test('mudança remota posterior atualiza o local', () async {
      await engine.start();
      await settle();

      remote.remoteSet(col, 'a', {'description': 'v1', 'updatedAt': now});
      await settle();
      remote.remoteSet(col, 'a', {
        'description': 'v2',
        'updatedAt': now.add(const Duration(minutes: 1)),
      });
      await settle();

      expect((await entries.get('a'))!.data['description'], 'v2');
    });

    test('exclusão remota apaga o documento local', () async {
      remote.docs[col] = {
        'a': {'description': 'x', 'updatedAt': now},
      };
      await engine.start();
      await settle();
      expect(await localDocs(), hasLength(1));

      remote.remoteDelete(col, 'a');
      await settle();

      expect(await localDocs(), isEmpty);
    });

    test('documento com escrita local pendente não é sobrescrito', () async {
      remote.hang = true; // push nunca completa: a pendência fica na outbox
      await engine.start();
      await settle();

      await entries.put('a', {'description': 'local'});
      await settle();

      remote.remoteSet(col, 'a', {
        'description': 'remoto',
        'updatedAt': now.add(const Duration(days: 1)),
      });
      await settle();

      expect((await entries.get('a'))!.data['description'], 'local');

      // Snapshot sem o doc também não apaga a pendência local.
      remote.remoteDelete(col, 'a');
      await settle();
      expect((await entries.get('a'))!.data['description'], 'local');
    });

    test('erro do listener vira estado de erro e syncNow reconecta', () async {
      await engine.start();
      await settle();

      remote.failCollection(col, const AuthException('sem permissão'));
      await settle();
      expect(engine.status.state, SyncState.error);
      expect(engine.status.message, 'sem permissão');

      remote.docs[col] = {
        'z': {'description': 'depois', 'updatedAt': now},
      };
      await engine.syncNow();
      await settle();

      expect(engine.status.state, SyncState.idle);
      expect(await localDocs(), hasLength(1));
    });
  });

  group('push', () {
    test('escrita local vai para o remoto e esvazia a outbox', () async {
      await engine.start();
      await settle();

      await entries.put('a', {'description': 'Aluguel', 'amount': 1500});
      await settle();

      expect(remote.writes, ['set $col/a']);
      expect(remote.docs[col]!['a']!['amount'], 1500);
      expect(remote.docs[col]!['a']!['updatedAt'], now);
      expect(await Outbox(local).count(local.raw), 0);
      expect(engine.status.state, SyncState.idle);
      expect(engine.status.pending, 0);
      expect(engine.status.lastSyncedAt, now);
    });

    test('exclusão local vai para o remoto', () async {
      remote.docs[col] = {
        'a': {'description': 'x', 'updatedAt': now},
      };
      await engine.start();
      await settle();

      await entries.delete('a');
      await settle();

      expect(remote.writes, ['delete $col/a']);
      expect(remote.docs[col], isEmpty);
      expect(await localDocs(), isEmpty);
    });

    test('sem rede a pendência fica guardada e é enviada depois', () async {
      remote.offline = true;
      await engine.start();
      await settle();

      await entries.put('a', {'description': 'offline'});
      await settle();

      expect(engine.status.state, SyncState.offline);
      expect(engine.status.pending, 1);
      expect(remote.docs[col], isNull);
      // O dado já está disponível localmente para a UI.
      expect((await entries.get('a'))!.data['description'], 'offline');

      remote.offline = false;
      await engine.syncNow();
      await settle();

      expect(engine.status.state, SyncState.idle);
      expect(engine.status.pending, 0);
      expect(remote.docs[col]!['a']!['description'], 'offline');
    });

    test('envio que não responde expira e conta como offline', () async {
      remote.hang = true;
      await engine.start();
      await settle();

      await entries.put('a', {'description': 'x'});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await settle();

      expect(engine.status.state, SyncState.offline);
      expect(engine.status.pending, 1);
    });

    test('snapshot remoto depois de offline dispara o reenvio', () async {
      remote.offline = true;
      await engine.start();
      await settle();
      await entries.put('a', {'description': 'x'});
      await settle();
      expect(engine.status.state, SyncState.offline);

      // Rede voltou: o Firestore entrega um snapshot de outra coleção/doc.
      remote.offline = false;
      remote.remoteSet(col, 'outro', {'description': 'y', 'updatedAt': now});
      await settle();

      expect(engine.status.state, SyncState.idle);
      expect(remote.docs[col]!.keys, containsAll(['a', 'outro']));
    });

    test('várias escritas no mesmo doc enviam só a última', () async {
      remote.offline = true;
      await engine.start();
      await settle();

      await entries.put('a', {'description': 'v1'});
      await entries.put('a', {'description': 'v2'});
      await entries.put('a', {'description': 'v3'});
      await settle();
      expect(engine.status.pending, 1);

      remote.offline = false;
      remote.writes.clear();
      await engine.syncNow();
      await settle();

      expect(remote.writes, ['set $col/a']);
      expect(remote.docs[col]!['a']!['description'], 'v3');
    });

    test('erro de permissão vira estado de erro com mensagem', () async {
      remote.writeError = const AuthException('Sem permissão para acessar os dados.');
      await engine.start();
      await settle();

      await entries.put('a', {'description': 'x'});
      await settle();

      expect(engine.status.state, SyncState.error);
      expect(engine.status.message, 'Sem permissão para acessar os dados.');
      expect(engine.status.pending, 1);
    });

    test('statusStream emite as transições', () async {
      final states = <SyncState>[];
      final sub = engine.statusStream.listen((s) => states.add(s.state));
      await engine.start();
      await settle();

      await entries.put('a', {'description': 'x'});
      await settle();
      await sub.cancel();

      expect(states, containsAllInOrder([SyncState.syncing, SyncState.idle]));
    });
  });

  test('stop cancela listeners e não envia mais nada', () async {
    await engine.start();
    await settle();
    await engine.stop();

    await entries.put('a', {'description': 'x'});
    await settle();

    expect(remote.writes, isEmpty);
    expect(engine.isRunning, isFalse);
  });

  test('retryDelay padrão cresce até 1 minuto', () {
    expect(SyncEngine.defaultRetryDelay(0), const Duration(seconds: 1));
    expect(SyncEngine.defaultRetryDelay(3), const Duration(seconds: 8));
    expect(SyncEngine.defaultRetryDelay(10), const Duration(seconds: 60));
  });
}

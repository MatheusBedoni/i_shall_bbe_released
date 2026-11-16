import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/data/local/local_database.dart';
import 'package:i_shall_be_released/core/data/sync/outbox.dart';
import 'package:i_shall_be_released/features/portfolio/data/datasources/local_portfolio_data_source.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset_transaction.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/dividend.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late LocalDatabase local;
  late LocalPortfolioDataSource ds;
  late Outbox outbox;
  var seq = 0;
  final now = DateTime(2026, 3, 1);

  setUp(() async {
    seq = 0;
    local = LocalDatabase(
      await newDatabaseFactoryMemory().openDatabase('portfolio.db'),
    );
    outbox = Outbox(local);
    ds = LocalPortfolioDataSource(
      local,
      clock: () => now,
      newId: () => 'id${seq++}',
    );
  });

  tearDown(() => local.close());

  Future<Asset> addAsset(String ticker) => ds.addAsset(
        Asset(id: '', ticker: ticker, name: ticker, assetClass: AssetClass.stock),
      );

  AssetTransaction tx(String assetId, {int daysAgo = 0}) => AssetTransaction(
        id: '',
        assetId: assetId,
        type: TransactionType.buy,
        quantity: 10,
        unitPrice: 20,
        date: now.subtract(Duration(days: daysAgo)),
      );

  test('ativos vêm ordenados por ticker', () async {
    await addAsset('VALE3');
    await addAsset('ABEV3');
    await addAsset('PETR4');

    final assets = await ds.watchAssets().first;
    expect(assets.map((a) => a.ticker), ['ABEV3', 'PETR4', 'VALE3']);
  });

  test('transações e proventos vêm do mais recente para o mais antigo',
      () async {
    final asset = await addAsset('PETR4');
    await ds.addTransaction(tx(asset.id, daysAgo: 5));
    await ds.addTransaction(tx(asset.id, daysAgo: 1));
    await ds.addTransaction(tx(asset.id, daysAgo: 3));
    await ds.addDividend(Dividend(
      id: '',
      assetId: asset.id,
      type: DividendType.dividend,
      amount: 1,
      date: now.subtract(const Duration(days: 9)),
    ));
    await ds.addDividend(Dividend(
      id: '',
      assetId: asset.id,
      type: DividendType.jcp,
      amount: 2,
      date: now,
    ));

    final txs = await ds.watchTransactions().first;
    expect(txs.map((t) => now.difference(t.date).inDays), [1, 3, 5]);
    final divs = await ds.watchDividends().first;
    expect(divs.map((d) => d.amount), [2, 1]);
  });

  test('deleteAsset apaga o ativo, suas transações e proventos', () async {
    final petr = await addAsset('PETR4');
    final vale = await addAsset('VALE3');
    await ds.addTransaction(tx(petr.id));
    await ds.addTransaction(tx(vale.id));
    await ds.addDividend(Dividend(
      id: '',
      assetId: petr.id,
      type: DividendType.dividend,
      amount: 1,
      date: now,
    ));

    await ds.deleteAsset(petr.id);

    expect((await ds.watchAssets().first).map((a) => a.id), [vale.id]);
    expect((await ds.watchTransactions().first).map((t) => t.assetId), [vale.id]);
    expect(await ds.watchDividends().first, isEmpty);

    final pending = await outbox.pending(local.raw);
    final deletes = pending.where((p) => p.op == OutboxOp.delete);
    expect(deletes.map((p) => p.key), unorderedEquals([
      'assets/${petr.id}',
      'transactions/id2',
      'dividends/id4',
    ]));
  });

  test('update preserva o id e enfileira o documento inteiro', () async {
    final asset = await addAsset('PETR4');
    await ds.updateAsset(asset.copyWith(name: 'Petrobras PN'));

    final updated = (await ds.watchAssets().first).single;
    expect(updated.id, asset.id);
    expect(updated.name, 'Petrobras PN');

    final pending = await outbox.pending(local.raw);
    expect(pending, hasLength(1));
    expect(pending.single.data!['name'], 'Petrobras PN');
    expect(pending.single.data!['ticker'], 'PETR4');
  });
}

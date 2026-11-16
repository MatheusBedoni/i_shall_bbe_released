import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset_transaction.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/dividend.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/quote.dart';
import 'package:i_shall_be_released/features/portfolio/domain/usecases/portfolio_usecases.dart';
import 'package:i_shall_be_released/features/portfolio/presentation/controllers/portfolio_controller.dart';

import 'fakes/in_memory_portfolio_repository.dart';

Future<void> _flush() => Future<void>.delayed(Duration.zero);

const _petr = Asset(id: '', ticker: 'petr4', name: 'Petrobras', assetClass: AssetClass.stock);
const _selic = Asset(
  id: '',
  ticker: 'TESOURO-SELIC',
  name: 'Tesouro Selic 2029',
  assetClass: AssetClass.fixedIncome,
);

void main() {
  late InMemoryPortfolioRepository repo;
  late FakeQuoteRepository quotes;
  late PortfolioController c;
  var now = DateTime(2025, 12, 12, 10);

  setUp(() {
    repo = InMemoryPortfolioRepository();
    quotes = FakeQuoteRepository();
    now = DateTime(2025, 12, 12, 10);
    c = PortfolioController(
      watchAssets: WatchAssets(repo),
      watchTransactions: WatchTransactions(repo),
      watchDividends: WatchDividends(repo),
      addAsset: AddAsset(repo),
      updateAsset: UpdateAsset(repo),
      deleteAsset: DeleteAsset(repo),
      addTransaction: AddTransaction(repo),
      updateTransaction: UpdateTransaction(repo),
      deleteTransaction: DeleteTransaction(repo),
      addDividend: AddDividend(repo),
      updateDividend: UpdateDividend(repo),
      deleteDividend: DeleteDividend(repo),
      getQuotes: GetQuotes(quotes),
      searchTickers: SearchTickers(quotes),
      computePositions: const ComputePositions(),
      clock: () => now,
    );
    c.start();
  });

  tearDown(() => c.dispose());

  test('carrega carteira vazia sem buscar cotações', () async {
    await _flush();
    expect(c.loading, isFalse);
    expect(c.assets, isEmpty);
    expect(c.summary?.positions, isEmpty);
    expect(quotes.calls, 0);
  });

  test('cadastrar ativo normaliza o ticker e dispara busca de cotação', () async {
    await _flush();
    quotes.quotes = {
      'PETR4': Quote(ticker: 'PETR4', price: 40, updatedAt: now),
    };
    final ok = await c.createAsset(_petr);
    await _flush();
    await _flush();
    expect(ok, isTrue);
    expect(c.assets.single.ticker, 'PETR4');
    expect(quotes.calls, 1);
    expect(quotes.lastRequested, ['PETR4']);
    expect(c.quotesUpdatedAt, now);
    expect(c.consumeMessage(), contains('PETR4'));
  });

  test('aporte gera posição com preço médio e valor de mercado', () async {
    await _flush();
    quotes.quotes = {
      'PETR4': Quote(ticker: 'PETR4', price: 40, updatedAt: now),
    };
    await c.createAsset(_petr);
    await _flush();
    await _flush();
    final asset = c.assets.single;
    final ok = await c.createTransaction(AssetTransaction(
      id: '',
      assetId: asset.id,
      type: TransactionType.buy,
      quantity: 10,
      unitPrice: 30,
      fees: 5,
      date: DateTime(2025, 12, 1),
    ));
    await _flush();
    expect(ok, isTrue);
    final p = c.positionOf(asset.id)!;
    expect(p.quantity, 10);
    expect(p.averagePrice, closeTo(30.5, 1e-9));
    expect(p.currentValue, 400);
    expect(c.summary!.totalInvested, closeTo(305, 1e-9));
    expect(c.openPositions, hasLength(1));
  });

  test('validação do aporte rejeita quantidade zero', () async {
    await _flush();
    await c.createAsset(_selic);
    await _flush();
    final ok = await c.createTransaction(AssetTransaction(
      id: '',
      assetId: c.assets.single.id,
      type: TransactionType.buy,
      quantity: 0,
      unitPrice: 1,
      date: now,
    ));
    expect(ok, isFalse);
    expect(c.error, 'A quantidade deve ser maior que zero.');
  });

  test('renda fixa não consulta cotações e vale o custo', () async {
    await _flush();
    await c.createAsset(_selic);
    await _flush();
    await _flush();
    expect(quotes.calls, 0);
    final asset = c.assets.single;
    await c.createTransaction(AssetTransaction(
      id: '',
      assetId: asset.id,
      type: TransactionType.buy,
      quantity: 1500,
      unitPrice: 1,
      date: DateTime(2025, 12, 5),
    ));
    await _flush();
    expect(c.positionOf(asset.id)!.currentValue, 1500);
  });

  test('refreshQuotes respeita o cache e força quando pedido', () async {
    await _flush();
    quotes.quotes = {
      'PETR4': Quote(ticker: 'PETR4', price: 40, updatedAt: now),
    };
    await c.createAsset(_petr);
    await _flush();
    await _flush();
    expect(quotes.calls, 1);

    await c.refreshQuotes();
    expect(quotes.calls, 1, reason: 'dentro do TTL não refaz a chamada');

    await c.refreshQuotes(force: true);
    expect(quotes.calls, 2);

    now = now.add(const Duration(minutes: 2));
    await c.refreshQuotes();
    expect(quotes.calls, 3, reason: 'após o TTL busca de novo');
  });

  test('falha de cotação não derruba a carteira e expõe quoteError', () async {
    await _flush();
    quotes.failure = const NetworkFailure();
    await c.createAsset(_petr);
    await _flush();
    await _flush();
    expect(c.error, isNull);
    expect(c.quoteError, 'Sem conexão com a internet.');
    expect(c.summary!.positions, hasLength(1));
  });

  test('excluir ativo remove transações e proventos', () async {
    await _flush();
    await c.createAsset(_selic);
    await _flush();
    final asset = c.assets.single;
    await c.createTransaction(AssetTransaction(
      id: '',
      assetId: asset.id,
      type: TransactionType.buy,
      quantity: 100,
      unitPrice: 1,
      date: now,
    ));
    await c.createDividend(Dividend(
      id: '',
      assetId: asset.id,
      type: DividendType.income,
      amount: 3,
      date: now,
    ));
    await _flush();
    expect(c.transactionsOf(asset.id), hasLength(1));
    expect(c.dividendsOf(asset.id), hasLength(1));

    final ok = await c.removeAsset(asset.id);
    await _flush();
    expect(ok, isTrue);
    expect(c.assets, isEmpty);
    expect(c.transactions, isEmpty);
    expect(c.dividends, isEmpty);
  });

  test('venda maior que a posição vira erro de cálculo', () async {
    await _flush();
    await c.createAsset(_selic);
    await _flush();
    final asset = c.assets.single;
    await c.createTransaction(AssetTransaction(
      id: '',
      assetId: asset.id,
      type: TransactionType.sell,
      quantity: 10,
      unitPrice: 1,
      date: now,
    ));
    await _flush();
    expect(c.error, contains('maior que a posição'));
  });
}

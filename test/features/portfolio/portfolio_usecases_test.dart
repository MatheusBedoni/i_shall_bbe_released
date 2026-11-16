import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/core/utils/streams.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset_transaction.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/quote.dart';
import 'package:i_shall_be_released/features/portfolio/domain/usecases/portfolio_usecases.dart';

import 'fakes/in_memory_portfolio_repository.dart';

const _petr = Asset(id: 'a1', ticker: 'PETR4', name: 'Petrobras', assetClass: AssetClass.stock);
const _selic = Asset(
  id: 'a2',
  ticker: 'SELIC',
  name: 'Tesouro Selic',
  assetClass: AssetClass.fixedIncome,
);

AssetTransaction _tx(
  String id,
  Asset asset,
  TransactionType type,
  DateTime date, {
  double qty = 1,
  double price = 10,
  double fees = 0,
}) =>
    AssetTransaction(
      id: id,
      assetId: asset.id,
      type: type,
      quantity: qty,
      unitPrice: price,
      fees: fees,
      date: date,
    );

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('validação', () {
    test('ativo precisa de código e nome; AddAsset normaliza o ticker', () async {
      final repo = InMemoryPortfolioRepository();
      final add = AddAsset(repo);
      expect(
        (await add(const Asset(id: '', ticker: ' ', name: 'x', assetClass: AssetClass.stock)))
            .failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await add(const Asset(id: '', ticker: 'petr4', name: ' ', assetClass: AssetClass.stock)))
            .failureOrNull,
        isA<ValidationFailure>(),
      );
      final saved = (await add(const Asset(
        id: '',
        ticker: ' petr4 ',
        name: ' Petrobras ',
        assetClass: AssetClass.stock,
      )))
          .valueOrNull!;
      expect(saved.ticker, 'PETR4');
      expect(saved.name, 'Petrobras');
    });

    test('transação exige ativo, quantidade e preço positivos e taxas não negativas', () {
      final d = DateTime(2025, 1, 1);
      expect(validateTransaction(_tx('t', const Asset(id: '', ticker: 'X', name: 'X', assetClass: AssetClass.other), TransactionType.buy, d)), isNotNull);
      expect(validateTransaction(_tx('t', _petr, TransactionType.buy, d, qty: 0)), isNotNull);
      expect(validateTransaction(_tx('t', _petr, TransactionType.buy, d, price: -1)), isNotNull);
      expect(validateTransaction(_tx('t', _petr, TransactionType.buy, d, fees: -1)), isNotNull);
      expect(validateTransaction(_tx('t', _petr, TransactionType.buy, d, qty: double.nan)), isNotNull);
      expect(validateTransaction(_tx('t', _petr, TransactionType.buy, d)), isNull);
    });
  });

  group('WatchContributions', () {
    test('buildContributions só considera compras de ativos existentes, mais recentes primeiro', () {
      final list = WatchContributions.buildContributions(
        assets: const [_petr, _selic],
        transactions: [
          _tx('t1', _petr, TransactionType.buy, DateTime(2025, 12, 1), qty: 10, price: 30, fees: 5),
          _tx('t2', _petr, TransactionType.sell, DateTime(2025, 12, 2)),
          _tx('t3', _selic, TransactionType.buy, DateTime(2025, 12, 15), qty: 500, price: 1),
          _tx('t4', const Asset(id: 'ghost', ticker: 'G', name: 'G', assetClass: AssetClass.other),
              TransactionType.buy, DateTime(2025, 12, 20)),
        ],
      );

      expect(list.map((c) => c.id), ['t3', 't1']);
      expect(list[0].amount, 500);
      expect(list[0].isAmountOnly, isTrue);
      expect(list[1].amount, 305);
      expect(list[1].isAmountOnly, isFalse);
      expect(list[1].asset, _petr);
    });

    test('stream combina ativos e transações do repositório', () async {
      final repo = InMemoryPortfolioRepository();
      final emitted = <int>[];
      final sub = WatchContributions(repo)().listen(
        (r) => emitted.add(r.valueOrNull!.length),
      );
      await _flush();
      expect(emitted, [0]);

      final asset = (await repo.addAsset(_petr)).valueOrNull!;
      await repo.addTransaction(_tx('', asset, TransactionType.buy, DateTime(2025, 12, 1)));
      await _flush();
      expect(emitted.last, 1);
      await sub.cancel();
    });
  });

  group('GetQuotes', () {
    test('só pede cotação de classes com mercado e deduplica tickers', () async {
      final quotes = FakeQuoteRepository()
        ..quotes = {'PETR4': Quote(ticker: 'PETR4', price: 1, updatedAt: DateTime(2025))};
      final r = await GetQuotes(quotes)(const [
        _petr,
        Asset(id: 'x', ticker: 'petr4', name: 'dup', assetClass: AssetClass.stock),
        _selic,
      ]);
      expect(quotes.lastRequested, ['PETR4']);
      expect(r.valueOrNull!.keys, ['PETR4']);
    });

    test('sem ativos cotáveis não chama a API', () async {
      final quotes = FakeQuoteRepository();
      final r = await GetQuotes(quotes)(const [_selic]);
      expect(quotes.calls, 0);
      expect(r.valueOrNull, isEmpty);
    });
  });

  group('SearchTickers', () {
    test('consultas curtas não chamam a API', () async {
      final quotes = FakeQuoteRepository()..failure = const ServerFailure();
      final r = await SearchTickers(quotes)('P');
      expect(r.valueOrNull, isEmpty);
    });
  });

  group('combineLatest2', () {
    test('emite só depois que ambos emitiram e a cada nova emissão', () async {
      final a = Stream<int>.fromIterable([1, 2]);
      final b = Stream<String>.fromIterable(['x']);
      final out = await combineLatest2(a, b, (int x, String y) => '$x$y').toList();
      // Ordem de entrega entre os dois streams é intercalada por microtask;
      // o invariante é: toda emissão usa os últimos valores de cada lado.
      expect(out, isNotEmpty);
      expect(out.last, '2x');
    });
  });
}

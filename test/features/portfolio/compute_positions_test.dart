import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset_transaction.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/dividend.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/quote.dart';
import 'package:i_shall_be_released/features/portfolio/domain/usecases/compute_positions.dart';

const petr = Asset(id: 'a1', ticker: 'PETR4', name: 'Petrobras', assetClass: AssetClass.stock);
const hglg = Asset(id: 'a2', ticker: 'HGLG11', name: 'CSHG Log', assetClass: AssetClass.fii);
const selic = Asset(
  id: 'a3',
  ticker: 'TESOURO-SELIC-2029',
  name: 'Tesouro Selic 2029',
  assetClass: AssetClass.fixedIncome,
);

int _seq = 0;
AssetTransaction _tx(
  Asset asset,
  TransactionType type,
  double qty,
  double price, {
  double fees = 0,
  int day = 1,
}) =>
    AssetTransaction(
      id: 't${_seq++}',
      assetId: asset.id,
      type: type,
      quantity: qty,
      unitPrice: price,
      fees: fees,
      date: DateTime(2025, 1, day),
    );

void main() {
  const useCase = ComputePositions();

  test('preço médio ponderado com taxas em compras sucessivas', () {
    final r = useCase(ComputePositionsParams(
      assets: const [petr],
      transactions: [
        _tx(petr, TransactionType.buy, 100, 30, fees: 10, day: 1), // 3010
        _tx(petr, TransactionType.buy, 100, 40, fees: 10, day: 2), // 4010
      ],
    )).valueOrNull!;

    final p = r.positions.single;
    expect(p.quantity, 200);
    expect(p.averagePrice, closeTo(35.10, 1e-9));
    expect(p.invested, closeTo(7020, 1e-9));
  });

  test('venda reduz quantidade, mantém preço médio e realiza lucro', () {
    final r = useCase(ComputePositionsParams(
      assets: const [petr],
      transactions: [
        _tx(petr, TransactionType.buy, 100, 30, day: 1),
        _tx(petr, TransactionType.sell, 40, 36, fees: 4, day: 2),
      ],
    )).valueOrNull!;

    final p = r.positions.single;
    expect(p.quantity, 60);
    expect(p.averagePrice, 30);
    // (40 * 36 - 4) - 40 * 30 = 1436 - 1200
    expect(p.realizedPnl, closeTo(236, 1e-9));
  });

  test('venda total zera a posição', () {
    final r = useCase(ComputePositionsParams(
      assets: const [petr],
      transactions: [
        _tx(petr, TransactionType.buy, 10, 10, day: 1),
        _tx(petr, TransactionType.sell, 10, 12, day: 2),
      ],
    )).valueOrNull!;
    final p = r.positions.single;
    expect(p.isOpen, isFalse);
    expect(p.quantity, 0);
    expect(p.averagePrice, 0);
    expect(p.realizedPnl, 20);
    expect(r.openPositions, isEmpty);
  });

  test('venda maior que a posição é rejeitada', () {
    final r = useCase(ComputePositionsParams(
      assets: const [petr],
      transactions: [
        _tx(petr, TransactionType.buy, 10, 10, day: 1),
        _tx(petr, TransactionType.sell, 11, 10, day: 2),
      ],
    ));
    expect(r.failureOrNull, isA<ValidationFailure>());
  });

  test('transações são ordenadas por data antes do cálculo', () {
    // Venda registrada "antes" da compra na lista, mas com data posterior.
    final r = useCase(ComputePositionsParams(
      assets: const [petr],
      transactions: [
        _tx(petr, TransactionType.sell, 5, 10, day: 5),
        _tx(petr, TransactionType.buy, 10, 10, day: 1),
      ],
    ));
    expect(r.isSuccess, isTrue);
    expect(r.valueOrNull!.positions.single.quantity, 5);
  });

  test('cotações, proventos e resumo da carteira', () {
    final r = useCase(ComputePositionsParams(
      assets: const [petr, hglg, selic],
      transactions: [
        _tx(petr, TransactionType.buy, 100, 30), // 3000
        _tx(hglg, TransactionType.buy, 10, 160), // 1600
        _tx(selic, TransactionType.buy, 1, 1400), // 1400, sem cotação
      ],
      dividends: [
        Dividend(id: 'd1', assetId: hglg.id, type: DividendType.income, amount: 11, date: DateTime(2025, 2, 1)),
        Dividend(id: 'd2', assetId: petr.id, type: DividendType.jcp, amount: 50, date: DateTime(2025, 2, 1)),
      ],
      quotes: {
        'PETR4': Quote(ticker: 'PETR4', price: 33, updatedAt: DateTime(2025, 3, 1)),
        'HGLG11': Quote(ticker: 'HGLG11', price: 150, updatedAt: DateTime(2025, 3, 1)),
      },
    )).valueOrNull!;

    final byTicker = {for (final p in r.positions) p.asset.ticker: p};
    expect(byTicker['PETR4']!.currentValue, 3300);
    expect(byTicker['PETR4']!.unrealizedPnl, 300);
    expect(byTicker['PETR4']!.unrealizedPnlPercent, closeTo(0.10, 1e-9));
    expect(byTicker['PETR4']!.dividendsReceived, 50);
    expect(byTicker['PETR4']!.totalReturn, 350);
    expect(byTicker['HGLG11']!.unrealizedPnl, -100);
    // Renda fixa sem cotação vale o custo.
    expect(byTicker['TESOURO-SELIC-2029']!.currentValue, 1400);

    expect(r.totalInvested, 6000);
    expect(r.totalCurrentValue, 3300 + 1500 + 1400);
    expect(r.totalUnrealizedPnl, 200);
    expect(r.totalDividends, 61);

    final alloc = r.allocationByClass;
    expect(alloc[AssetClass.stock], closeTo(3300 / 6200, 1e-9));
    expect(alloc[AssetClass.fii], closeTo(1500 / 6200, 1e-9));
    expect(alloc[AssetClass.fixedIncome], closeTo(1400 / 6200, 1e-9));
    expect(alloc.values.fold(0.0, (a, b) => a + b), closeTo(1, 1e-9));
  });

  test('transação de ativo inexistente é sinalizada', () {
    final r = useCase(ComputePositionsParams(
      assets: const [petr],
      transactions: [_tx(hglg, TransactionType.buy, 1, 1)],
    ));
    expect(r.failureOrNull, isA<ValidationFailure>());
  });
}

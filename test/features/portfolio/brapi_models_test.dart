import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/features/portfolio/data/models/brapi_models.dart';
import 'package:i_shall_be_released/features/portfolio/domain/entities/asset.dart';

void main() {
  group('quotesFromJson', () {
    test('lê preço, variação (em fração) e horário, indexando pelo ticker pedido', () {
      final quotes = BrapiModels.quotesFromJson({
        'results': [
          {
            'requestedSymbol': 'axia5',
            'symbol': 'AXIA3',
            'changed': true,
            'data': {
              'regularMarketPrice': 38.1,
              'regularMarketChangePercent': 1.25,
              'regularMarketTime': '2025-01-10T20:07:00.000Z',
            },
          },
        ],
        'requestedAt': '2025-01-10T20:08:00.000Z',
        'took': 12,
      });

      final q = quotes['AXIA5']!;
      expect(q.ticker, 'AXIA5');
      expect(q.price, 38.1);
      expect(q.changePercent, closeTo(0.0125, 1e-12));
      expect(q.updatedAt, DateTime.utc(2025, 1, 10, 20, 7));
      expect(quotes.containsKey('AXIA3'), isFalse);
    });

    test('ignora itens sem preço e respostas sem results', () {
      expect(BrapiModels.quotesFromJson({'error': true}), isEmpty);
      expect(
        BrapiModels.quotesFromJson({
          'results': [
            {'symbol': 'XXXX3', 'data': {}},
            'lixo',
          ],
        }),
        isEmpty,
      );
    });

    test('usa o relógio informado quando falta o horário', () {
      final now = DateTime(2025, 3, 1);
      final q = BrapiModels.quotesFromJson({
        'results': [
          {'symbol': 'PETR4', 'data': {'regularMarketPrice': 10}},
        ],
      }, now: now)['PETR4']!;
      expect(q.updatedAt, now);
      expect(q.changePercent, isNull);
    });
  });

  group('suggestionsFromJson', () {
    test('mapeia subType para a classe do ativo e prefere longName', () {
      final list = BrapiModels.suggestionsFromJson({
        'results': [
          {
            'symbol': 'HGLG11',
            'name': 'CSHG LOG',
            'longName': 'CSHG Logística FII',
            'assetType': 'fund',
            'subType': 'fii',
            'quote': {'lastPrice': 160.5},
          },
          {'symbol': 'IVVB11', 'name': 'ISHARES S&P500', 'longName': null, 'subType': 'etf'},
          {'symbol': 'AAPL34', 'name': 'APPLE', 'assetType': 'bdr', 'subType': 'bdr'},
          {'symbol': 'TAEE11', 'name': 'TAESA UNT', 'assetType': 'stock', 'subType': 'unit'},
          {'name': 'sem symbol'},
        ],
      });

      expect(list, hasLength(4));
      expect(list[0].ticker, 'HGLG11');
      expect(list[0].name, 'CSHG Logística FII');
      expect(list[0].assetClass, AssetClass.fii);
      expect(list[0].lastPrice, 160.5);
      expect(list[1].name, 'ISHARES S&P500');
      expect(list[1].assetClass, AssetClass.etf);
      expect(list[2].assetClass, AssetClass.bdr);
      expect(list[3].assetClass, AssetClass.stock);
    });

    test('assetClassFrom cai no assetType quando subType é desconhecido', () {
      expect(BrapiModels.assetClassFrom(assetType: 'fund', subType: null), AssetClass.fii);
      expect(BrapiModels.assetClassFrom(assetType: 'bdr', subType: 'x'), AssetClass.bdr);
      expect(BrapiModels.assetClassFrom(assetType: null, subType: null), AssetClass.stock);
      expect(BrapiModels.assetClassFrom(assetType: 'stock', subType: 'fi-agro'), AssetClass.fii);
    });
  });
}

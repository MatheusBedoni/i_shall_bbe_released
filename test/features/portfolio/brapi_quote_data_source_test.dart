import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:i_shall_be_released/core/error/exceptions.dart';
import 'package:i_shall_be_released/features/portfolio/data/datasources/brapi_quote_data_source.dart';

http.Response _quote(String symbol, double price) => http.Response(
      jsonEncode({
        'results': [
          {
            'requestedSymbol': symbol,
            'symbol': symbol,
            'data': {
              'regularMarketPrice': price,
              'regularMarketChangePercent': 0.5,
              'regularMarketTime': '2025-01-10T20:07:00.000Z',
            },
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('busca um ticker por chamada e envia o token no header', () async {
    final seen = <Uri>[];
    String? auth;
    final client = MockClient((req) async {
      seen.add(req.url);
      auth = req.headers['Authorization'];
      final symbol = req.url.queryParameters['symbols']!;
      return _quote(symbol, symbol == 'PETR4' ? 40 : 150);
    });
    final ds = BrapiQuoteDataSource(client: client, token: 'abc');

    final quotes = await ds.getQuotes(['PETR4', 'HGLG11']);

    expect(seen.map((u) => u.queryParameters['symbols']), ['PETR4', 'HGLG11']);
    expect(seen.first.path, '/api/v2/stocks/quote');
    expect(auth, 'Bearer abc');
    expect(quotes['PETR4']!.price, 40);
    expect(quotes['HGLG11']!.price, 150);
    expect(quotes['PETR4']!.changePercent, closeTo(0.005, 1e-12));
  });

  test('sem token: 401 em um ticker não impede os demais (resultado parcial)', () async {
    final client = MockClient((req) async {
      final symbol = req.url.queryParameters['symbols']!;
      if (symbol == 'PETR4') return _quote(symbol, 40);
      return http.Response('{"error":true}', 401);
    });
    final ds = BrapiQuoteDataSource(client: client);

    final quotes = await ds.getQuotes(['XPTO3', 'PETR4']);
    expect(quotes.keys, ['PETR4']);
  });

  test('sem nenhuma cotação e 401, explica que falta o token', () async {
    final client = MockClient((_) async => http.Response('', 401));
    final ds = BrapiQuoteDataSource(client: client);

    expect(
      () => ds.getQuotes(['XPTO3']),
      throwsA(isA<ServerException>().having((e) => e.message, 'message', contains('BRAPI_TOKEN'))),
    );
  });

  test('404 é ticker sem cotação; 429 interrompe e falha se nada veio', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      final symbol = req.url.queryParameters['symbols']!;
      if (symbol == 'NADA3') return http.Response('', 404);
      return http.Response('', 429);
    });
    final ds = BrapiQuoteDataSource(client: client);

    await expectLater(
      () => ds.getQuotes(['NADA3', 'PETR4', 'VALE3']),
      throwsA(isA<ServerException>().having((e) => e.message, 'message', contains('Limite'))),
    );
    expect(calls, 2, reason: 'para no 429, não consulta VALE3');
  });

  test('falha de rede vira NetworkException', () async {
    final client = MockClient((_) async => throw http.ClientException('offline'));
    final ds = BrapiQuoteDataSource(client: client);
    expect(() => ds.getQuotes(['PETR4']), throwsA(isA<NetworkException>()));
  });

  test('searchTickers usa /api/v2/tickers com search e limit', () async {
    Uri? seen;
    final client = MockClient((req) async {
      seen = req.url;
      return http.Response(
        jsonEncode({
          'results': [
            {'symbol': 'PETR4', 'name': 'PETROBRAS PN', 'assetType': 'stock', 'subType': 'stock'},
          ],
        }),
        200,
      );
    });
    final ds = BrapiQuoteDataSource(client: client);

    final list = await ds.searchTickers('petr');
    expect(seen!.path, '/api/v2/tickers');
    expect(seen!.queryParameters['search'], 'petr');
    expect(seen!.queryParameters['limit'], '12');
    expect(list.single.ticker, 'PETR4');
  });
}

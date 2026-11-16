import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/quote.dart';
import '../../domain/entities/ticker_suggestion.dart';
import '../models/brapi_models.dart';

abstract interface class QuoteRemoteDataSource {
  Future<Map<String, Quote>> getQuotes(List<String> tickers);
  Future<List<TickerSuggestion>> searchTickers(String query);
}

/// Cliente da brapi.dev (ações, FIIs, ETFs e BDRs da B3).
///
/// O plano gratuito aceita **um ticker por chamada**, por isso as cotações
/// são buscadas uma a uma, em sequência. Sem token funcionam apenas alguns
/// tickers de teste (PETR4, VALE3, MGLU3, ITUB4, HGLG11, MXRF11); para a
/// carteira inteira, gere uma chave em https://brapi.dev/dashboard e coloque
/// em `BRAPI_TOKEN` no `.env` (ou `--dart-define=BRAPI_TOKEN=...`).
final class BrapiQuoteDataSource implements QuoteRemoteDataSource {
  BrapiQuoteDataSource({
    required this._client,
    String? token,
    Uri? baseUri,
  })  : _token = (token ?? '').trim(),
        _base = baseUri ?? Uri.parse('https://brapi.dev');

  final http.Client _client;
  final String _token;
  final Uri _base;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  @override
  Future<Map<String, Quote>> getQuotes(List<String> tickers) async {
    final out = <String, Quote>{};
    var needsToken = false;
    var rateLimited = false;
    for (final ticker in tickers) {
      final uri = _base.replace(
        path: '/api/v2/stocks/quote',
        queryParameters: {'symbols': ticker},
      );
      final res = await _get(uri);
      switch (res.statusCode) {
        case 200:
          out.addAll(BrapiModels.quotesFromJson(res.json!));
        case 404:
          // Ticker sem cotação: simplesmente não entra no mapa.
          continue;
        case 401 || 403:
          // Sem token só os tickers de teste respondem; segue para os outros.
          needsToken = true;
        case 429:
          rateLimited = true;
          break;
        default:
          throw ServerException('brapi respondeu ${res.statusCode}.');
      }
      if (rateLimited) break;
    }
    // Com cotações parciais o usuário ainda vê a carteira; só falha quando
    // nada veio e sabemos o motivo.
    if (out.isEmpty && rateLimited) {
      throw const ServerException(
        'Limite de consultas da brapi atingido. Tente mais tarde.',
      );
    }
    if (out.isEmpty && needsToken) {
      throw const ServerException(
        'A brapi exige um token para cotar estes ativos. '
        'Defina BRAPI_TOKEN no .env (veja .env.example).',
      );
    }
    return out;
  }

  @override
  Future<List<TickerSuggestion>> searchTickers(String query) async {
    final uri = _base.replace(
      path: '/api/v2/tickers',
      queryParameters: {'search': query, 'limit': '12'},
    );
    final res = await _get(uri);
    switch (res.statusCode) {
      case 200:
        return BrapiModels.suggestionsFromJson(res.json!);
      case 404:
        return const [];
      case 429:
        throw const ServerException(
          'Limite de consultas da brapi atingido. Tente mais tarde.',
        );
      default:
        throw ServerException('brapi respondeu ${res.statusCode}.');
    }
  }

  /// Faz GET e devolve status + JSON (quando 200). Falhas de rede viram
  /// exceções da camada data; códigos HTTP são decididos por quem chama.
  Future<_BrapiResponse> _get(Uri uri) async {
    final http.Response res;
    try {
      res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } on http.ClientException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('Tempo esgotado ao consultar cotações.');
    } on Object catch (e) {
      throw ServerException('Falha ao consultar cotações: $e');
    }

    if (res.statusCode != 200) return _BrapiResponse(res.statusCode, null);
    final body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) return _BrapiResponse(200, body);
    throw const ServerException('Resposta inesperada da brapi.');
  }
}

final class _BrapiResponse {
  const _BrapiResponse(this.statusCode, this.json);
  final int statusCode;
  final Map<String, dynamic>? json;
}

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuração externa do app (chaves de API, etc.).
///
/// Ordem de precedência de cada valor:
/// 1. `--dart-define=NOME=valor` em build time;
/// 2. arquivo `.env` na raiz do projeto (carregado por [load]);
/// 3. vazio.
///
/// O `.env` não vai para o git; use `.env.example` como modelo.
abstract final class AppConfig {
  static const _brapiFromDefine = String.fromEnvironment('BRAPI_TOKEN');

  static bool _loaded = false;

  /// Carrega o `.env`. A ausência do arquivo não é erro: o app funciona sem
  /// token (só com os tickers de teste da brapi).
  static Future<void> load() async {
    if (_loaded) return;
    try {
      await dotenv.load(fileName: '.env');
    } on Object catch (e) {
      debugPrint('AppConfig: .env não carregado ($e).');
    }
    _loaded = true;
  }

  /// Token da brapi.dev. Vazio quando não configurado.
  static String get brapiToken =>
      env('BRAPI_TOKEN', fromDefine: _brapiFromDefine);

  /// Retorna o valor de [key] (priorizando [fromDefine], depois `.env`), ou `''`.
  static String env(String key, {String fromDefine = ''}) {
    if (fromDefine.isNotEmpty) return fromDefine;
    return (_env(key) ?? '').trim();
  }

  /// Retorna o valor obrigatório de [key] ou lança [StateError] caso esteja vazio.
  static String requireEnv(String key, {String fromDefine = ''}) {
    final value = env(key, fromDefine: fromDefine);
    if (value.isEmpty) {
      throw StateError(
        'Variável "$key" não definida. Configure-a no arquivo .env (veja .env.example).',
      );
    }
    return value;
  }

  static String? _env(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.maybeGet(key);
  }
}

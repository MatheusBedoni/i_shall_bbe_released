import 'package:sembast/sembast.dart';
import 'package:sembast/timestamp.dart';

import '../../error/exceptions.dart';
import '../sync/doc_record.dart';

/// Banco de dados local do usuário corrente (um arquivo por `uid`).
///
/// Usa o sembast: banco NoSQL puro Dart, orientado a documentos como o
/// Firestore, que roda em Android, iOS, desktop e web (via IndexedDB) e em
/// memória nos testes. Cada coleção do Firestore vira um *store* local com
/// os mesmos ids de documento, o que torna a sincronização um espelho 1:1.
final class LocalDatabase {
  LocalDatabase(this.raw);

  /// Banco sembast subjacente. Exposto para streams e transações.
  final Database raw;

  StoreRef<String, DocData> store(String collection) =>
      stringMapStoreFactory.store(collection);

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      raw.transaction(action);

  Future<void> close() => raw.close();
}

/// Conversão entre o formato neutro ([DocData], com [DateTime]) e os valores
/// que o sembast persiste (seu próprio [Timestamp]).
abstract final class LocalCodec {
  static DocData encode(DocData data) =>
      {for (final e in data.entries) e.key: _encode(e.value)};

  static DocData decode(Map<String, Object?> data) =>
      {for (final e in data.entries) e.key: _decode(e.value)};

  static Object? _encode(Object? v) => switch (v) {
        DateTime d => Timestamp.fromDateTime(d),
        Map m => {for (final e in m.entries) e.key as String: _encode(e.value)},
        List l => l.map(_encode).toList(),
        _ => v,
      };

  static Object? _decode(Object? v) => switch (v) {
        Timestamp t => t.toDateTime(),
        Map m => {for (final e in m.entries) e.key as String: _decode(e.value)},
        List l => l.map(_decode).toList(),
        _ => v,
      };
}

/// Tradução de erros do sembast em exceções da camada data.
abstract final class LocalErrors {
  static Exception translate(DatabaseException e) =>
      CacheException(e.message);

  static Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      throw translate(e);
    }
  }

  /// Para usar em `stream.handleError(LocalErrors.rethrow_)`.
  static Never rethrow_(Object error) {
    if (error is DatabaseException) throw translate(error);
    throw error;
  }
}

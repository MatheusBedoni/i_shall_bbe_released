import 'package:cloud_firestore/cloud_firestore.dart';

import '../error/exceptions.dart';

/// Tradução de erros do Firestore em exceções da camada data, compartilhada
/// por todos os datasources remotos.
abstract final class FirestoreErrors {
  static Exception translate(FirebaseException e) => switch (e.code) {
        'permission-denied' =>
          const AuthException('Sem permissão para acessar os dados.'),
        'unavailable' => const NetworkException(),
        _ => ServerException(e.message ?? e.code),
      };

  /// Executa [action] convertendo [FirebaseException] em exceções da data.
  static Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw translate(e);
    }
  }

  /// Para usar em `stream.handleError(FirestoreErrors.rethrow_)`.
  static Never rethrow_(Object error) {
    if (error is FirebaseException) throw translate(error);
    throw error;
  }
}

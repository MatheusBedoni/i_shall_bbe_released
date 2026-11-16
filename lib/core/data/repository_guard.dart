import 'dart:async';

import '../error/exceptions.dart';
import '../error/failures.dart';
import '../utils/result.dart';

/// Mapeia exceções da camada data em falhas de domínio.
Failure toFailure(Object error) => switch (error) {
      AuthException(:final message) => AuthFailure(message),
      NetworkException(:final message) => NetworkFailure(message),
      ServerException(:final message) => ServerFailure(message),
      CacheException(:final message) => CacheFailure(message),
      _ => const UnexpectedFailure(),
    };

/// Converte chamadas e streams de um datasource em [Result]s, de modo que
/// nenhuma exceção da data atravesse para o domínio.
mixin RepositoryGuard {
  Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Object catch (e) {
      return Error(toFailure(e));
    }
  }

  Stream<Result<T>> wrapStream<T>(Stream<T> Function() source) {
    late StreamController<Result<T>> controller;
    StreamSubscription<T>? sub;
    controller = StreamController<Result<T>>(
      onListen: () {
        try {
          sub = source().listen(
            (value) => controller.add(Success(value)),
            onError: (Object e) => controller.add(Error(toFailure(e))),
            onDone: controller.close,
          );
        } on Object catch (e) {
          controller
            ..add(Error(toFailure(e)))
            ..close();
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}

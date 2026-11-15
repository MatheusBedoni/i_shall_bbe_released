import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/core/utils/result.dart';

void main() {
  group('Result', () {
    test('fold chama onSuccess em Success', () {
      const result = Success<int>(2);
      final out = result.fold((f) => 'erro', (v) => 'ok $v');
      expect(out, 'ok 2');
    });

    test('fold chama onError em Error', () {
      const result = Error<int>(ServerFailure('boom'));
      final out = result.fold((f) => f.message, (v) => 'ok');
      expect(out, 'boom');
    });

    test('map transforma apenas o sucesso', () {
      expect(const Success<int>(2).map((v) => v * 2), const Success<int>(4));
      const failure = CacheFailure();
      expect(
        const Error<int>(failure).map((v) => v * 2),
        const Error<int>(failure),
      );
    });

    test('valueOrNull e failureOrNull', () {
      expect(const Success<int>(1).valueOrNull, 1);
      expect(const Success<int>(1).failureOrNull, isNull);
      expect(const Error<int>(UnexpectedFailure()).valueOrNull, isNull);
      expect(
        const Error<int>(UnexpectedFailure()).failureOrNull,
        isA<UnexpectedFailure>(),
      );
    });
  });
}

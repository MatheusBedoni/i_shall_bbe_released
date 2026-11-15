import 'package:flutter_test/flutter_test.dart';
import 'package:i_shall_be_released/core/error/failures.dart';
import 'package:i_shall_be_released/core/utils/result.dart';
import 'package:i_shall_be_released/features/auth/domain/entities/app_user.dart';
import 'package:i_shall_be_released/features/auth/domain/repositories/auth_repository.dart';
import 'package:i_shall_be_released/features/auth/domain/usecases/auth_usecases.dart';
import 'package:i_shall_be_released/features/auth/presentation/controllers/auth_controller.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.failWith});
  final Failure? failWith;
  final calls = <String>[];

  static const user = AppUser(id: 'u1', email: 'a@b.com');

  Future<Result<AppUser>> _respond(String call) async {
    calls.add(call);
    return failWith == null ? const Success(user) : Error(failWith!);
  }

  @override
  Future<Result<AppUser>> signInWithEmail({required String email, required String password}) =>
      _respond('signIn:$email');

  @override
  Future<Result<AppUser>> signUpWithEmail({required String email, required String password}) =>
      _respond('signUp:$email');

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    calls.add('reset:$email');
    return const Success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    calls.add('signOut');
    return const Success(null);
  }

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> watchAuthState() => const Stream.empty();
}

void main() {
  group('EmailCredentials.validate', () {
    test('e-mail inválido', () {
      expect(
        const EmailCredentials(email: 'x', password: '123456').validate(),
        isA<ValidationFailure>(),
      );
    });
    test('senha curta', () {
      expect(
        const EmailCredentials(email: 'a@b.com', password: '12345').validate(),
        isA<ValidationFailure>(),
      );
    });
    test('válido', () {
      expect(
        const EmailCredentials(email: 'a@b.com', password: '123456').validate(),
        isNull,
      );
    });
  });

  test('SignInWithEmail valida antes de chamar o repositório e faz trim', () async {
    final repo = _FakeAuthRepository();
    final useCase = SignInWithEmail(repo);

    final bad = await useCase(const EmailCredentials(email: 'x', password: '1'));
    expect(bad.failureOrNull, isA<ValidationFailure>());
    expect(repo.calls, isEmpty);

    final ok = await useCase(const EmailCredentials(email: '  a@b.com ', password: '123456'));
    expect(ok.valueOrNull, _FakeAuthRepository.user);
    expect(repo.calls, ['signIn:a@b.com']);
  });

  group('AuthController', () {
    AuthController controller(AuthRepository repo) => AuthController(
          signInWithEmail: SignInWithEmail(repo),
          signUpWithEmail: SignUpWithEmail(repo),
          sendPasswordReset: SendPasswordReset(repo),
          signOut: SignOut(repo),
        );

    test('alterna modo e usa o use case correspondente', () async {
      final repo = _FakeAuthRepository();
      final c = controller(repo);
      expect(c.mode, AuthMode.signIn);
      c.toggleMode();
      expect(c.mode, AuthMode.signUp);
      await c.submit(email: 'a@b.com', password: '123456');
      expect(repo.calls, ['signUp:a@b.com']);
      expect(c.error, isNull);
      expect(c.loading, isFalse);
    });

    test('falha do repositório vira mensagem de erro', () async {
      final repo = _FakeAuthRepository(failWith: const AuthFailure('E-mail ou senha incorretos.'));
      final c = controller(repo);
      final user = await c.submit(email: 'a@b.com', password: '123456');
      expect(user, isNull);
      expect(c.error, 'E-mail ou senha incorretos.');
    });

    test('resetPassword exige e-mail e informa envio', () async {
      final repo = _FakeAuthRepository();
      final c = controller(repo);
      await c.resetPassword('');
      expect(c.error, isNotNull);
      expect(repo.calls, isEmpty);

      await c.resetPassword('a@b.com');
      expect(c.info, contains('redefinir'));
      expect(repo.calls, ['reset:a@b.com']);
    });
  });
}

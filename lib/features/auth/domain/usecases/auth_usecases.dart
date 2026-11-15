import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

final class EmailCredentials {
  const EmailCredentials({required this.email, required this.password});
  final String email;
  final String password;

  Failure? validate() {
    final e = email.trim();
    if (e.isEmpty || !e.contains('@') || !e.contains('.')) {
      return const ValidationFailure('Informe um e-mail válido.');
    }
    if (password.length < 6) {
      return const ValidationFailure(
        'A senha deve ter pelo menos 6 caracteres.',
      );
    }
    return null;
  }
}

final class SignInWithEmail implements UseCase<AppUser, EmailCredentials> {
  const SignInWithEmail(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<AppUser>> call(EmailCredentials params) async {
    final invalid = params.validate();
    if (invalid != null) return Error(invalid);
    return _repo.signInWithEmail(
      email: params.email.trim(),
      password: params.password,
    );
  }
}

final class SignUpWithEmail implements UseCase<AppUser, EmailCredentials> {
  const SignUpWithEmail(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<AppUser>> call(EmailCredentials params) async {
    final invalid = params.validate();
    if (invalid != null) return Error(invalid);
    return _repo.signUpWithEmail(
      email: params.email.trim(),
      password: params.password,
    );
  }
}

final class SendPasswordReset implements UseCase<void, String> {
  const SendPasswordReset(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<void>> call(String email) =>
      _repo.sendPasswordReset(email.trim());
}

final class SignOut implements UseCase<void, NoParams> {
  const SignOut(this._repo);
  final AuthRepository _repo;

  @override
  Future<Result<void>> call(NoParams params) => _repo.signOut();
}

final class WatchAuthState {
  const WatchAuthState(this._repo);
  final AuthRepository _repo;

  Stream<AppUser?> call() => _repo.watchAuthState();
}

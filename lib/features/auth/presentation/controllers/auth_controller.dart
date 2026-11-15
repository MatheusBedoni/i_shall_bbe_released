import 'package:flutter/foundation.dart';

import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/auth_usecases.dart';

enum AuthMode { signIn, signUp }

/// Controla o formulário de login/cadastro.
final class AuthController extends ChangeNotifier {
  AuthController({
    required this.signInWithEmail,
    required this.signUpWithEmail,
    required this.sendPasswordReset,
    required this.signOut,
  });

  final SignInWithEmail signInWithEmail;
  final SignUpWithEmail signUpWithEmail;
  final SendPasswordReset sendPasswordReset;
  final SignOut signOut;

  AuthMode _mode = AuthMode.signIn;
  bool _loading = false;
  String? _error;
  String? _info;

  AuthMode get mode => _mode;
  bool get loading => _loading;
  String? get error => _error;
  String? get info => _info;

  void toggleMode() {
    _mode = _mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn;
    _error = null;
    _info = null;
    notifyListeners();
  }

  /// Retorna o usuário em caso de sucesso; `null` em caso de erro (exposto em
  /// [error]). A navegação é feita pelo AuthGate, que escuta o estado de auth.
  Future<AppUser?> submit({required String email, required String password}) async {
    final creds = EmailCredentials(email: email, password: password);
    final useCase = _mode == AuthMode.signIn ? signInWithEmail : signUpWithEmail;
    final result = await _run(() => useCase(creds));
    return result.valueOrNull;
  }

  Future<void> resetPassword(String email) async {
    if (email.trim().isEmpty) {
      _error = 'Informe o e-mail para recuperar a senha.';
      notifyListeners();
      return;
    }
    final result = await _run(() => sendPasswordReset(email));
    if (result.isSuccess) {
      _info = 'Enviamos um e-mail para redefinir sua senha.';
      notifyListeners();
    }
  }

  Future<void> logout() => signOut(const NoParams());

  Future<Result<T>> _run<T>(Future<Result<T>> Function() action) async {
    _loading = true;
    _error = null;
    _info = null;
    notifyListeners();
    final result = await action();
    _loading = false;
    _error = result.failureOrNull?.message;
    notifyListeners();
    return result;
  }
}

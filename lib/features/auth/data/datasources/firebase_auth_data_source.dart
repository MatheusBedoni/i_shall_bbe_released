import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/app_user.dart';

abstract interface class AuthDataSource {
  Stream<AppUser?> authState();
  AppUser? get currentUser;
  Future<AppUser> signIn(String email, String password);
  Future<AppUser> signUp(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

final class FirebaseAuthDataSource implements AuthDataSource {
  const FirebaseAuthDataSource(this._auth);
  final fb.FirebaseAuth _auth;

  @override
  Stream<AppUser?> authState() => _auth.authStateChanges().map(_toUser);

  @override
  AppUser? get currentUser => _toUser(_auth.currentUser);

  @override
  Future<AppUser> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _toUser(cred.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_translate(e.code));
    }
  }

  @override
  Future<AppUser> signUp(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _toUser(cred.user)!;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_translate(e.code));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_translate(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static AppUser? _toUser(fb.User? user) => user == null
      ? null
      : AppUser(
          id: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
        );

  static String _translate(String code) => switch (code) {
        'invalid-email' => 'E-mail inválido.',
        'user-disabled' => 'Usuário desativado.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'E-mail ou senha incorretos.',
        'email-already-in-use' => 'Este e-mail já está cadastrado.',
        'weak-password' => 'Senha muito fraca.',
        'too-many-requests' => 'Muitas tentativas. Tente novamente mais tarde.',
        'network-request-failed' => 'Sem conexão com a internet.',
        _ => 'Falha na autenticação ($code).',
      };
}

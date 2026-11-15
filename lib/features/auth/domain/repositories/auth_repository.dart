import '../../../../core/utils/result.dart';
import '../entities/app_user.dart';

abstract interface class AuthRepository {
  /// Emite o usuário atual, ou `null` quando deslogado.
  Stream<AppUser?> watchAuthState();

  AppUser? get currentUser;

  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<Result<void>> sendPasswordReset(String email);

  Future<Result<void>> signOut();
}

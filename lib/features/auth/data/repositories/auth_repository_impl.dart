import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_auth_data_source.dart';

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._ds);
  final AuthDataSource _ds;

  @override
  Stream<AppUser?> watchAuthState() => _ds.authState();

  @override
  AppUser? get currentUser => _ds.currentUser;

  @override
  Future<Result<AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() => _ds.signIn(email, password));

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(() => _ds.signUp(email, password));

  @override
  Future<Result<void>> sendPasswordReset(String email) =>
      _guard(() => _ds.sendPasswordReset(email));

  @override
  Future<Result<void>> signOut() => _guard(_ds.signOut);

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on AuthException catch (e) {
      return Error(AuthFailure(e.message));
    } on NetworkException catch (e) {
      return Error(NetworkFailure(e.message));
    } on Object {
      return const Error(UnexpectedFailure());
    }
  }
}

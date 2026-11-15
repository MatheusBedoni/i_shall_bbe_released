import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/data/datasources/firebase_auth_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/budget/data/datasources/budget_remote_data_source.dart';
import '../../features/budget/data/repositories/budget_repository_impl.dart';
import '../../features/budget/domain/repositories/budget_repository.dart';
import '../../features/budget/domain/usecases/budget_usecases.dart';
import '../../features/budget/presentation/controllers/budget_controller.dart';

/// Composition root: o único lugar que conhece as implementações concretas.
///
/// Feito à mão para não depender de pacotes; pode ser migrado para `get_it`
/// ou `riverpod` sem mudar nenhuma outra camada.
final class InjectionContainer {
  InjectionContainer._({
    required this._firebaseAuth,
    required this._firestore,
  });

  static InjectionContainer? _instance;

  static InjectionContainer get instance =>
      _instance ??= InjectionContainer._(
        firebaseAuth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
      );

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  // ---------------------------------------------------------------- Auth
  late final AuthRepository authRepository =
      AuthRepositoryImpl(FirebaseAuthDataSource(_firebaseAuth));

  late final WatchAuthState watchAuthState = WatchAuthState(authRepository);
  late final SignOut signOut = SignOut(authRepository);

  AuthController newAuthController() => AuthController(
        signInWithEmail: SignInWithEmail(authRepository),
        signUpWithEmail: SignUpWithEmail(authRepository),
        sendPasswordReset: SendPasswordReset(authRepository),
        signOut: signOut,
      );

  // -------------------------------------------------------------- Budget
  late final BudgetRepository budgetRepository = BudgetRepositoryImpl(
    FirestoreBudgetDataSource(
      db: _firestore,
      currentUid: () => _firebaseAuth.currentUser?.uid,
    ),
  );

  BudgetController newBudgetController() => BudgetController(
        watchEntries: WatchEntries(budgetRepository),
        watchAllocationRule: WatchAllocationRule(budgetRepository),
        addEntry: AddEntry(budgetRepository),
        updateEntry: UpdateEntry(budgetRepository),
        deleteEntry: DeleteEntry(budgetRepository),
        copyEntries: CopyEntries(budgetRepository),
        saveAllocationRule: SaveAllocationRule(budgetRepository),
        computeSummary: const ComputeBudgetSummary(),
      );

  /// Útil em testes para começar com um grafo limpo.
  static void reset() => _instance = null;
}

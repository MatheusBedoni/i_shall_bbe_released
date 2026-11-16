import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/data/local/local_database.dart';
import '../../core/data/local/open_user_database.dart';
import '../../core/data/sync/doc_record.dart';
import '../../core/data/sync/firestore_remote_store.dart';
import '../../core/data/sync/sync_engine.dart';
import '../../features/auth/data/datasources/firebase_auth_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_usecases.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/budget/data/datasources/local_budget_data_source.dart';
import '../../features/budget/data/repositories/budget_repository_impl.dart';
import '../../features/budget/domain/repositories/budget_repository.dart';
import '../../features/budget/domain/usecases/budget_usecases.dart';
import '../../features/budget/presentation/controllers/budget_controller.dart';
import '../../features/goals/data/datasources/local_goal_data_source.dart';
import '../../features/goals/data/repositories/goal_repository_impl.dart';
import '../../features/goals/domain/repositories/goal_repository.dart';
import '../../features/goals/domain/usecases/goal_usecases.dart';
import '../../features/goals/presentation/controllers/goals_controller.dart';
import '../../features/portfolio/data/datasources/brapi_quote_data_source.dart';
import '../../features/portfolio/data/datasources/local_portfolio_data_source.dart';
import '../../features/portfolio/data/repositories/portfolio_repository_impl.dart';
import '../../features/portfolio/data/repositories/quote_repository_impl.dart';
import '../../features/portfolio/domain/repositories/portfolio_repository.dart';
import '../../features/portfolio/domain/repositories/quote_repository.dart';
import '../../features/portfolio/domain/usecases/portfolio_usecases.dart';
import '../../features/portfolio/presentation/controllers/portfolio_controller.dart';

/// Composition root: o único lugar que conhece as implementações concretas.
///
/// Feito à mão para não depender de pacotes; pode ser migrado para `get_it`
/// ou `riverpod` sem mudar nenhuma outra camada.
///
/// Os dados do usuário vivem num [UserSession]: banco local + motor de sync +
/// repositórios, abertos no login e fechados no logout.
final class InjectionContainer {
  InjectionContainer._({
    required this._firebaseAuth,
    required this._firestore,
    required this._httpClient,
  });

  static InjectionContainer? _instance;

  static InjectionContainer get instance => _instance ??= InjectionContainer._(
        firebaseAuth: FirebaseAuth.instance,
        // O cache offline do próprio Firestore fica desligado: o banco local
        // (sembast) e a outbox são a única fonte de verdade offline, evitando
        // duas filas de escrita concorrentes.
        firestore: FirebaseFirestore.instance
          ..settings = const Settings(persistenceEnabled: false),
        httpClient: http.Client(),
      );

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

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

  // -------------------------------------------------------------- Sessão
  /// Abre o banco local do usuário e liga a sincronização com o Firestore.
  Future<UserSession> openSession(String uid) async {
    final local = LocalDatabase(await openUserDatabase(uid));
    final sync = SyncEngine(
      local: local,
      remote: FirestoreRemoteStore(db: _firestore, uid: uid),
      collections: SyncCollections.all,
    );
    await sync.start();
    return UserSession._(
      uid: uid,
      local: local,
      sync: sync,
      budgetRepository: BudgetRepositoryImpl(LocalBudgetDataSource(local)),
      portfolioRepository:
          PortfolioRepositoryImpl(LocalPortfolioDataSource(local)),
      goalRepository: GoalRepositoryImpl(LocalGoalDataSource(local)),
    );
  }

  // -------------------------------------------------------------- Budget
  BudgetController newBudgetController(UserSession session) =>
      BudgetController(
        watchEntries: WatchEntries(session.budgetRepository),
        watchAllocationRule: WatchAllocationRule(session.budgetRepository),
        watchContributions: WatchContributions(session.portfolioRepository),
        addEntry: AddEntry(session.budgetRepository),
        updateEntry: UpdateEntry(session.budgetRepository),
        deleteEntry: DeleteEntry(session.budgetRepository),
        copyEntries: CopyEntries(session.budgetRepository),
        saveAllocationRule: SaveAllocationRule(session.budgetRepository),
        computeSummary: const ComputeBudgetSummary(),
      );

  // ----------------------------------------------------------- Portfolio
  /// Token lido do `.env` (ou `--dart-define=BRAPI_TOKEN`), ver [AppConfig].
  late final QuoteRepository quoteRepository = QuoteRepositoryImpl(
    BrapiQuoteDataSource(client: _httpClient, token: AppConfig.brapiToken),
  );

  PortfolioController newPortfolioController(UserSession session) =>
      PortfolioController(
        watchAssets: WatchAssets(session.portfolioRepository),
        watchTransactions: WatchTransactions(session.portfolioRepository),
        watchDividends: WatchDividends(session.portfolioRepository),
        addAsset: AddAsset(session.portfolioRepository),
        updateAsset: UpdateAsset(session.portfolioRepository),
        deleteAsset: DeleteAsset(session.portfolioRepository),
        addTransaction: AddTransaction(session.portfolioRepository),
        updateTransaction: UpdateTransaction(session.portfolioRepository),
        deleteTransaction: DeleteTransaction(session.portfolioRepository),
        addDividend: AddDividend(session.portfolioRepository),
        updateDividend: UpdateDividend(session.portfolioRepository),
        deleteDividend: DeleteDividend(session.portfolioRepository),
        getQuotes: GetQuotes(quoteRepository),
        searchTickers: SearchTickers(quoteRepository),
        computePositions: const ComputePositions(),
      );

  // --------------------------------------------------------------- Metas
  GoalsController newGoalsController(UserSession session) => GoalsController(
        watchGoals: WatchGoals(session.goalRepository),
        addGoal: AddGoal(session.goalRepository),
        updateGoal: UpdateGoal(session.goalRepository),
        deleteGoal: DeleteGoal(session.goalRepository),
        computeSnapshots: const ComputeGoalSnapshots(),
      );

  /// Útil em testes para começar com um grafo limpo.
  static void reset() => _instance = null;
}

/// Grafo de dependências de um usuário logado. Descartar fecha o banco local
/// e para a sincronização.
final class UserSession {
  UserSession._({
    required this.uid,
    required this._local,
    required this.sync,
    required this.budgetRepository,
    required this.portfolioRepository,
    required this.goalRepository,
  });

  final String uid;
  final LocalDatabase _local;
  final SyncEngine sync;
  final BudgetRepository budgetRepository;
  final PortfolioRepository portfolioRepository;
  final GoalRepository goalRepository;

  Future<void> dispose() async {
    await sync.dispose();
    await _local.close();
  }
}

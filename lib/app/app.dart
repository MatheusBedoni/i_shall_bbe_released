import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/usecase/usecase.dart';
import '../features/auth/domain/entities/app_user.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/widgets/auth_gate.dart';
import '../features/budget/presentation/controllers/budget_controller.dart';
import '../features/budget/presentation/pages/budget_page.dart';
import '../features/goals/presentation/controllers/goals_controller.dart';
import '../features/goals/presentation/pages/goals_page.dart';
import '../features/portfolio/presentation/controllers/portfolio_controller.dart';
import '../features/portfolio/presentation/pages/portfolio_page.dart';
import '../features/shell/account_page.dart';
import '../features/shell/home_shell.dart';
import 'di/injection_container.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final di = InjectionContainer.instance;
    return MaterialApp(
      title: 'I Shall Be Released',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: AuthGate(
        authState: di.watchAuthState(),
        initialUser: di.authRepository.currentUser,
        signedOut: LoginPage(controller: di.newAuthController()),
        signedIn: (user) => _SignedInShell(key: ValueKey(user.id), user: user),
      ),
    );
  }
}

/// Abre a sessão do usuário (banco local + sync) e mantém os controllers
/// vivos enquanto ele está logado. Trocar de usuário recria tudo (ver `key`).
class _SignedInShell extends StatefulWidget {
  const _SignedInShell({super.key, required this.user});
  final AppUser user;

  @override
  State<_SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends State<_SignedInShell> {
  UserSession? _session;
  BudgetController? _budget;
  PortfolioController? _portfolio;
  GoalsController? _goals;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final di = InjectionContainer.instance;
    try {
      final session = await di.openSession(widget.user.id);
      if (!mounted) {
        await session.dispose();
        return;
      }
      setState(() {
        _session = session;
        _budget = di.newBudgetController(session);
        _portfolio = di.newPortfolioController(session);
        _goals = di.newGoalsController(session);
        _error = null;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _budget?.dispose();
    _portfolio?.dispose();
    _goals?.dispose();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final di = InjectionContainer.instance;
    final session = _session;
    final error = _error;

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_outlined, size: 48),
                const SizedBox(height: 12),
                const Text('Não foi possível abrir os dados locais.'),
                const SizedBox(height: 4),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _open();
                  },
                  child: const Text('Tentar de novo'),
                ),
                TextButton(
                  onPressed: () => di.signOut(const NoParams()),
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return HomeShell(
      tabs: [
        ShellTab(
          label: 'Orçamento',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          builder: (_) =>
              BudgetPage(controller: _budget!, portfolio: _portfolio!),
        ),
        ShellTab(
          label: 'Carteira',
          icon: Icons.pie_chart_outline,
          selectedIcon: Icons.pie_chart,
          builder: (_) => PortfolioPage(controller: _portfolio!),
        ),
        ShellTab(
          label: 'Metas',
          icon: Icons.flag_outlined,
          selectedIcon: Icons.flag,
          builder: (_) => GoalsPage(controller: _goals!, portfolio: _portfolio!),
        ),
        ShellTab(
          label: 'Conta',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          builder: (_) => AccountPage(
            user: widget.user,
            sync: session.sync,
            onSignOut: () => di.signOut(const NoParams()),
          ),
        ),
      ],
    );
  }
}

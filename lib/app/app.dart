import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/usecase/usecase.dart';
import '../features/auth/domain/entities/app_user.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/widgets/auth_gate.dart';
import '../features/budget/presentation/controllers/budget_controller.dart';
import '../features/budget/presentation/pages/budget_page.dart';
import '../features/shell/account_page.dart';
import '../features/shell/coming_soon_page.dart';
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
        signedIn: (user) => _SignedInShell(user: user),
      ),
    );
  }
}

/// Mantém os controllers vivos enquanto o usuário está logado.
class _SignedInShell extends StatefulWidget {
  const _SignedInShell({required this.user});
  final AppUser user;

  @override
  State<_SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends State<_SignedInShell> {
  late final BudgetController _budget =
      InjectionContainer.instance.newBudgetController();

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final di = InjectionContainer.instance;
    return HomeShell(
      tabs: [
        ShellTab(
          label: 'Orçamento',
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          builder: (_) => BudgetPage(controller: _budget),
        ),
        ShellTab(
          label: 'Carteira',
          icon: Icons.pie_chart_outline,
          selectedIcon: Icons.pie_chart,
          builder: (_) => const ComingSoonPage(
            title: 'Carteira',
            icon: Icons.pie_chart_outline,
            features: [
              'Cadastro de ativos e aportes',
              'Posição consolidada e preço médio',
              'Cotações em tempo real',
              'Proventos recebidos',
            ],
          ),
        ),
        ShellTab(
          label: 'Metas',
          icon: Icons.flag_outlined,
          selectedIcon: Icons.flag,
          builder: (_) => const ComingSoonPage(
            title: 'Metas',
            icon: Icons.flag_outlined,
            features: [
              'Metas financeiras com prazo',
              'Projeção com juros compostos',
              'Aporte necessário para o prazo',
            ],
          ),
        ),
        ShellTab(
          label: 'Conta',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          builder: (_) => AccountPage(
            user: widget.user,
            onSignOut: () => di.signOut(const NoParams()),
          ),
        ),
      ],
    );
  }
}

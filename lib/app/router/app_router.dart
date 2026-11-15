import 'package:flutter/material.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../di/injection_container.dart';
import 'app_routes.dart';

/// Mapeia nomes de rota para páginas, resolvendo dependências via DI.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final di = InjectionContainer.instance;

    return switch (settings.name) {
      AppRoutes.home => MaterialPageRoute(
          settings: settings,
          builder: (_) => HomePage(controller: di.newHomeController()),
        ),
      _ => MaterialPageRoute(
          settings: settings,
          builder: (_) => Scaffold(
            body: Center(child: Text('Rota não encontrada: ${settings.name}')),
          ),
        ),
    };
  }
}

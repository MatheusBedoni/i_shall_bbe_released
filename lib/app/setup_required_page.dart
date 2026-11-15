import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Exibida quando o Firebase ainda não foi configurado no projeto.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Configuração necessária',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Firebase não configurado',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Rode na raiz do projeto:\n\n'
                    'dart pub global activate flutterfire_cli\n'
                    'flutterfire configure\n\n'
                    'e reinicie o app.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$error',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

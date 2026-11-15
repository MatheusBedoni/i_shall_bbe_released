import 'package:flutter/material.dart';

import '../auth/domain/entities/app_user.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.user, required this.onSignOut});

  final AppUser user;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 36,
            child: Text(
              (user.displayName ?? user.email).substring(0, 1).toUpperCase(),
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.displayName ?? user.email,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          if (user.displayName != null)
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

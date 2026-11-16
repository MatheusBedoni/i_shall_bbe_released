import 'package:flutter/material.dart';

import '../../core/data/sync/sync_engine.dart';
import '../../core/data/sync/sync_status.dart';
import '../../core/utils/dates.dart';
import '../auth/domain/entities/app_user.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({
    super.key,
    required this.user,
    required this.sync,
    required this.onSignOut,
  });

  final AppUser user;
  final SyncEngine sync;
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
          const SizedBox(height: 24),
          SyncStatusTile(sync: sync),
          const SizedBox(height: 24),
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

/// Estado da sincronização com a nuvem e botão para forçar o envio.
class SyncStatusTile extends StatelessWidget {
  const SyncStatusTile({super.key, required this.sync});

  final SyncEngine sync;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: sync.statusStream,
      initialData: sync.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncStatus.initial;
        final (icon, title) = switch (status.state) {
          SyncState.idle when status.hasPending => (
              Icons.cloud_queue,
              'Aguardando para sincronizar',
            ),
          SyncState.idle => (Icons.cloud_done_outlined, 'Sincronizado'),
          SyncState.syncing => (Icons.cloud_sync_outlined, 'Sincronizando…'),
          SyncState.offline => (Icons.cloud_off_outlined, 'Sem conexão'),
          SyncState.error => (Icons.error_outline, 'Erro ao sincronizar'),
        };
        final details = <String>[
          if (status.hasPending)
            '${status.pending} ${status.pending == 1 ? 'alteração pendente' : 'alterações pendentes'}',
          if (status.message != null) status.message!,
          if (status.lastSyncedAt != null)
            'Último envio: ${Dates.withTime(status.lastSyncedAt!)}',
          if (!status.hasPending && status.lastSyncedAt == null)
            'Suas alterações ficam salvas no aparelho e vão para a nuvem automaticamente.',
        ];
        return Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: details.isEmpty ? null : Text(details.join('\n')),
            isThreeLine: details.length > 1,
            trailing: IconButton(
              tooltip: 'Sincronizar agora',
              icon: const Icon(Icons.sync),
              onPressed:
                  status.state == SyncState.syncing ? null : sync.syncNow,
            ),
          ),
        );
      },
    );
  }
}

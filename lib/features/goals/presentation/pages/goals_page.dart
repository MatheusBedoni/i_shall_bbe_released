import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/percent.dart';
import '../../../portfolio/domain/entities/position.dart';
import '../../../portfolio/presentation/controllers/portfolio_controller.dart';
import '../../domain/entities/goal_snapshot.dart';
import '../controllers/goals_controller.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_form_dialog.dart';
import 'goal_detail_page.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({
    super.key,
    required this.controller,
    required this.portfolio,
  });

  final GoalsController controller;

  /// Fornece as posições (com cotação) dos ativos vinculados às metas.
  final PortfolioController portfolio;

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  GoalsController get c => widget.controller;
  PortfolioController get p => widget.portfolio;

  @override
  void initState() {
    super.initState();
    c.start();
    p.start();
    c.addListener(_showTransientMessage);
  }

  @override
  void dispose() {
    c.removeListener(_showTransientMessage);
    super.dispose();
  }

  void _showTransientMessage() {
    final msg = c.consumeMessage();
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<Position> get _positions => p.summary?.positions ?? const [];

  Future<void> _newGoal() async {
    final goal = await showGoalFormDialog(context, positions: _positions);
    if (goal == null) return;
    await c.createGoal(goal);
  }

  void _open(GoalSnapshot s) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GoalDetailPage(
          controller: c,
          portfolio: p,
          goalId: s.goal.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      body: ListenableBuilder(
        listenable: Listenable.merge([c, p]),
        builder: (context, _) {
          if (c.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final snapshots = c.snapshots(_positions);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    c.error!,
                    style: TextStyle(color: scheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (snapshots.isEmpty)
                _EmptyState(onCreate: _newGoal)
              else ...[
                _OverviewCard(snapshots: snapshots),
                const SizedBox(height: 12),
                for (final s in snapshots) ...[
                  GoalCard(snapshot: s, onTap: () => _open(s)),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 72),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newGoal,
        icon: const Icon(Icons.add),
        label: const Text('Nova meta'),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.snapshots});
  final List<GoalSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final saved = snapshots.fold(0.0, (s, g) => s + g.savedAmount);
    final target = snapshots.fold(0.0, (s, g) => s + g.goal.targetAmount);
    final reached = snapshots.where((g) => g.isReached).length;
    final linked = snapshots.fold(0.0, (s, g) => s + g.linkedValue);
    final fraction = target <= 0 ? 0.0 : (saved / target).clamp(0, 1).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Todas as metas', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              Money.format(saved),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
            Text(
              'de ${Money.format(target)} · ${Percent.format(fraction, decimals: 0)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: fraction, minHeight: 6),
            ),
            const SizedBox(height: 8),
            Text(
              '$reached de ${snapshots.length} atingida(s)'
              '${linked > 0 ? ' · ${Money.format(linked)} vindos da carteira' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.flag_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Nenhuma meta ainda', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Defina um objetivo (reserva de emergência, viagem, entrada do '
              'apê…) e vincule os ativos da carteira que estão guardando esse '
              'dinheiro. O progresso acompanha seus aportes e cotações.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Criar primeira meta'),
            ),
          ],
        ),
      ),
    );
  }
}

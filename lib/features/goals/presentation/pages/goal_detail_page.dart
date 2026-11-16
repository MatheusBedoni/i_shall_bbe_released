import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/percent.dart';
import '../../../portfolio/domain/entities/position.dart';
import '../../../portfolio/presentation/controllers/portfolio_controller.dart';
import '../../domain/entities/goal_snapshot.dart';
import '../../domain/usecases/project_goal.dart';
import '../controllers/goals_controller.dart';
import '../widgets/goal_form_dialog.dart';
import '../widgets/goal_texts.dart';
import '../widgets/projection_chart.dart';

/// Detalhe de uma meta: progresso, projeção e ativos vinculados.
class GoalDetailPage extends StatelessWidget {
  const GoalDetailPage({
    super.key,
    required this.controller,
    required this.portfolio,
    required this.goalId,
  });

  final GoalsController controller;
  final PortfolioController portfolio;
  final String goalId;

  GoalsController get c => controller;

  List<Position> get _positions => portfolio.summary?.positions ?? const [];

  Future<void> _edit(BuildContext context, GoalSnapshot s) async {
    final updated = await showGoalFormDialog(
      context,
      existing: s.goal,
      positions: _positions,
    );
    if (updated == null) return;
    await c.editGoal(updated);
  }

  Future<void> _delete(BuildContext context, GoalSnapshot s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${s.goal.name}"?'),
        content: const Text(
          'Os ativos vinculados continuam na carteira; só a meta é removida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await c.removeGoal(s.goal.id);
    if (ok && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([c, portfolio]),
      builder: (context, _) {
        final s = c.snapshotOf(goalId, _positions);
        if (s == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Esta meta não existe mais.')),
          );
        }
        final goal = s.goal;
        final projection = s.projection;
        final now = DateTime.now();
        final deadlineMonth = goal.deadline == null
            ? null
            : ProjectGoal.monthsBetween(now, goal.deadline!);

        return Scaffold(
          appBar: AppBar(
            title: Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Editar meta',
                onPressed: () => _edit(context, s),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Excluir meta',
                onPressed: () => _delete(context, s),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
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
              _ProgressCard(snapshot: s),
              const SizedBox(height: 12),
              _StatsGrid(snapshot: s, deadlineMonth: deadlineMonth),
              const SizedBox(height: 12),
              if (projection != null) ...[
                _ProjectionCard(
                  snapshot: s,
                  projection: projection,
                  deadlineMonth: deadlineMonth,
                ),
                const SizedBox(height: 12),
              ],
              _LinkedAssetsCard(snapshot: s, onLink: () => _edit(context, s)),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.snapshot});
  final GoalSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = snapshot;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Saldo da meta', style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              Money.format(s.savedAmount),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: s.isReached ? scheme.gain : scheme.primary,
              ),
            ),
            Text(
              'de ${Money.format(s.goal.targetAmount)} · ${Percent.format(s.progress, decimals: 0)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s.progress,
                minHeight: 10,
                color: s.isReached ? scheme.gain : scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.isReached
                  ? 'Meta atingida!'
                  : 'Faltam ${Money.format(s.remaining)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: s.isReached ? scheme.gain : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (s.goal.isLinked)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Carteira ${Money.format(s.linkedValue)} + fora da carteira '
                  '${Money.format(s.goal.currentAmount)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.snapshot, required this.deadlineMonth});
  final GoalSnapshot snapshot;
  final int? deadlineMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = snapshot;
    final goal = s.goal;
    final p = s.projection;
    final months = p?.monthsToTarget;
    final required = p?.requiredMonthlyContribution;
    final behind = s.onTrackForDeadline == false;

    final stats = <_Stat>[
      _Stat(
        title: 'Previsão',
        value: s.isReached
            ? 'Atingida'
            : months == null
                ? 'Não atinge'
                : GoalTexts.months(months),
        note: s.isReached
            ? 'Parabéns!'
            : months == null
                ? 'Aumente o aporte ou a rentabilidade'
                : 'com ${Money.format(goal.monthlyContribution)}/mês',
        color: s.isReached ? scheme.gain : null,
      ),
      _Stat(
        title: 'Aporte planejado',
        value: Money.format(goal.monthlyContribution),
        note: '${Percent.format(goal.annualRate)} a.a. esperados',
      ),
      if (goal.deadline != null) ...[
        _Stat(
          title: 'Prazo',
          value: Dates.short(goal.deadline!),
          note: deadlineMonth == null || deadlineMonth! <= 0
              ? 'Prazo chegou'
              : 'em ${GoalTexts.months(deadlineMonth!)}',
        ),
        _Stat(
          title: 'Aporte necessário',
          value: required == null ? '—' : Money.format(required),
          note: behind
              ? 'acima do planejado'
              : required == 0
                  ? 'o saldo atual já basta'
                  : 'por mês para cumprir o prazo',
          color: behind ? scheme.error : scheme.gain,
        ),
        if (p?.projectedAtDeadline != null)
          _Stat(
            title: 'Projetado no prazo',
            value: Money.format(p!.projectedAtDeadline!),
            note: p.projectedAtDeadline! >= goal.targetAmount
                ? 'cumpre a meta'
                : 'faltariam ${Money.format(goal.targetAmount - p.projectedAtDeadline!)}',
            color: p.projectedAtDeadline! >= goal.targetAmount ? scheme.gain : scheme.error,
          ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 96,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, i) => _StatCard(stat: stats[i]),
        );
      },
    );
  }
}

class _Stat {
  const _Stat({
    required this.title,
    required this.value,
    required this.note,
    this.color,
  });
  final String title;
  final String value;
  final String note;
  final Color? color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(stat.title,
                style: theme.textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              stat.value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: stat.color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(stat.note,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({
    required this.snapshot,
    required this.projection,
    required this.deadlineMonth,
  });
  final GoalSnapshot snapshot;
  final GoalProjection projection;
  final int? deadlineMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = snapshot.goal;
    // Mostra até a meta ou o prazo (o que for mais longe), no mínimo 1 ano e,
    // quando nunca atinge, 10 anos.
    final end = [
      projection.monthsToTarget ?? 120,
      deadlineMonth ?? 0,
      12,
    ].reduce(math.max);
    final visible = projection.timeline
        .take(math.min(end, projection.timeline.length - 1) + 1)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Projeção', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Saldo com aportes de ${Money.format(goal.monthlyContribution)} por mês '
              'rendendo ${Percent.format(goal.annualRate)} ao ano. Toque para ver o valor.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ProjectionChart(
              timeline: visible,
              target: goal.targetAmount,
              deadlineMonth: deadlineMonth,
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedAssetsCard extends StatelessWidget {
  const _LinkedAssetsCard({required this.snapshot, required this.onLink});
  final GoalSnapshot snapshot;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = snapshot;
    final missing = s.missingAssetIds;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Investimentos vinculados',
                      style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: onLink,
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(s.goal.isLinked ? 'Alterar' : 'Vincular'),
                ),
              ],
            ),
            if (!s.goal.isLinked)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Vincule ativos da carteira para que o saldo desta meta '
                  'acompanhe seus aportes e cotações automaticamente.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else ...[
              for (final p in s.linkedPositions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.trending_up, color: scheme.investment),
                  title: Text('${p.asset.ticker} · ${p.asset.name}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    p.isOpen
                        ? '${p.asset.assetClass.label} · investido ${Money.format(p.invested)}'
                        : 'Sem posição aberta',
                  ),
                  trailing: Text(
                    Money.format(p.currentValue),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              if (missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${missing.length} ativo(s) vinculado(s) não está(ão) mais na '
                    'carteira. Edite a meta para desvinculá-los.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Fora da carteira', style: theme.textTheme.bodyMedium),
                  ),
                  Text(Money.format(s.goal.currentAmount)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    Money.format(s.savedAmount),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

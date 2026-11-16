import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/percent.dart';
import '../../domain/entities/goal_snapshot.dart';
import 'goal_texts.dart';

/// Cartão de uma meta na lista: progresso, previsão e ativos vinculados.
class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.snapshot, required this.onTap});

  final GoalSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = snapshot;
    final goal = s.goal;
    final projection = s.projection;

    final String forecast;
    Color? forecastColor;
    if (s.isReached) {
      forecast = 'Meta atingida';
      forecastColor = scheme.gain;
    } else if (projection?.monthsToTarget != null) {
      forecast = 'Previsão: ${GoalTexts.months(projection!.monthsToTarget!)}';
      if (s.onTrackForDeadline == false) forecastColor = scheme.error;
    } else {
      forecast = 'Sem aporte não há previsão';
      forecastColor = scheme.onSurfaceVariant;
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    s.isReached ? Icons.flag : Icons.flag_outlined,
                    color: s.isReached ? scheme.gain : scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (goal.deadline != null)
                    Text(
                      Dates.short(goal.deadline!),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Money.format(s.savedAmount)} de ${Money.format(goal.targetAmount)}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    Percent.format(s.progress, decimals: 0),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: s.progress,
                  minHeight: 8,
                  color: s.isReached ? scheme.gain : scheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      forecast,
                      style: theme.textTheme.bodySmall?.copyWith(color: forecastColor),
                    ),
                  ),
                  if (goal.isLinked)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link, size: 16, color: scheme.investment),
                        const SizedBox(width: 4),
                        Text(
                          s.linkedPositions.isEmpty
                              ? 'ativos não encontrados'
                              : s.linkedPositions.map((p) => p.asset.ticker).join(', '),
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

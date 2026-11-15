import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/percent.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_summary.dart';
import '../../domain/entities/entry_type.dart';

/// Seção de uma categoria: total, orçamento/restante, barra de uso e lista.
class EntrySection extends StatelessWidget {
  const EntrySection({
    super.key,
    required this.type,
    required this.entries,
    required this.envelope,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final EntryType type;
  final List<BudgetEntry> entries;

  /// `null` para ganhos (não possuem envelope).
  final EnvelopeSummary? envelope;
  final VoidCallback onAdd;
  final ValueChanged<BudgetEntry> onEdit;
  final ValueChanged<BudgetEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = entries.fold(0.0, (s, e) => s + e.amount);
    final env = envelope;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(type.label, style: theme.textTheme.titleMedium),
                ),
                Text(
                  Money.format(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (env != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Orçamento: ${Money.format(env.budget)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    'Restante: ${Money.format(env.remaining)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: env.isOverBudget ? scheme.error : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: env.usedFraction.clamp(0, 1).toDouble(),
                  minHeight: 6,
                  color: env.isOverBudget ? scheme.error : scheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${Percent.format(env.usedFraction)} utilizado',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum lançamento ainda.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              ...entries.map(
                (e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Money.format(e.amount)),
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => onEdit(e),
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => onDelete(e),
                      ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

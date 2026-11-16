import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/percent.dart';
import '../../../portfolio/domain/entities/contribution.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/budget_summary.dart';
import '../../domain/entities/entry_type.dart';

/// Envelope de investimentos do mês: aportes vindos da carteira (vinculados
/// a um ativo cadastrado) + lançamentos avulsos.
class InvestmentSection extends StatelessWidget {
  const InvestmentSection({
    super.key,
    required this.envelope,
    required this.contributions,
    required this.entries,
    required this.onAddContribution,
    required this.onEditContribution,
    required this.onDeleteContribution,
    required this.onAddEntry,
    required this.onEditEntry,
    required this.onDeleteEntry,
  });

  final EnvelopeSummary envelope;
  final List<Contribution> contributions;
  final List<BudgetEntry> entries;
  final VoidCallback onAddContribution;
  final ValueChanged<Contribution> onEditContribution;
  final ValueChanged<Contribution> onDeleteContribution;
  final VoidCallback onAddEntry;
  final ValueChanged<BudgetEntry> onEditEntry;
  final ValueChanged<BudgetEntry> onDeleteEntry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                  child: Text(EntryType.investment.label,
                      style: theme.textTheme.titleMedium),
                ),
                Text(
                  Money.format(env.spent),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.investment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('Orçamento: ${Money.format(env.budget)}',
                      style: theme.textTheme.bodySmall),
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
                color: env.isOverBudget ? scheme.error : scheme.investment,
              ),
            ),
            const SizedBox(height: 4),
            Text('${Percent.format(env.usedFraction)} utilizado',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('Aportes na carteira', style: theme.textTheme.labelLarge),
            if (contributions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhum aporte neste mês. Registre um aporte em um ativo '
                  'cadastrado e ele entra aqui automaticamente.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              ...contributions.map(
                (c) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.trending_up, color: scheme.investment),
                  title: Text('${c.asset.ticker} · ${c.asset.name}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_detail(c)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(Money.format(c.amount)),
                      IconButton(
                        tooltip: 'Editar aporte',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => onEditContribution(c),
                      ),
                      IconButton(
                        tooltip: 'Excluir aporte',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => onDeleteContribution(c),
                      ),
                    ],
                  ),
                ),
              ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Lançamentos avulsos', style: theme.textTheme.labelLarge),
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
                        onPressed: () => onEditEntry(e),
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => onDeleteEntry(e),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onAddEntry,
                  child: const Text('Lançamento avulso'),
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  onPressed: onAddContribution,
                  icon: const Icon(Icons.add),
                  label: const Text('Aporte'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _detail(Contribution c) {
    final tx = c.transaction;
    if (c.isAmountOnly) return Dates.short(tx.date);
    final qty = tx.quantity == tx.quantity.roundToDouble()
        ? tx.quantity.toStringAsFixed(0)
        : tx.quantity.toStringAsFixed(4);
    return '${Dates.short(tx.date)} · $qty × ${Money.format(tx.unitPrice)}';
  }
}

import 'package:flutter/material.dart';

import '../../domain/entities/budget_period.dart';

/// Seletor de período: ano com setas + os 12 meses como chips clicáveis.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.period,
    required this.onSelect,
    required this.onToday,
  });

  final BudgetPeriod period;
  final ValueChanged<BudgetPeriod> onSelect;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = BudgetPeriod.now();
    final isCurrent = period == now;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.outlined(
              tooltip: 'Ano anterior',
              onPressed: () => onSelect(BudgetPeriod(year: period.year - 1, month: period.month)),
              icon: const Icon(Icons.chevron_left),
            ),
            SizedBox(
              width: 96,
              child: Text(
                '${period.year}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton.outlined(
              tooltip: 'Próximo ano',
              onPressed: () => onSelect(BudgetPeriod(year: period.year + 1, month: period.month)),
              icon: const Icon(Icons.chevron_right),
            ),
            if (!isCurrent) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onToday,
                icon: const Icon(Icons.today_outlined, size: 18),
                label: const Text('Hoje'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var m = 1; m <= 12; m++)
              _MonthChip(
                label: BudgetPeriod.monthNames[m - 1],
                selected: m == period.month,
                isToday: period.year == now.year && m == now.month,
                onTap: () => onSelect(BudgetPeriod(year: period.year, month: m)),
                scheme: scheme,
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.selected,
    required this.isToday,
    required this.onTap,
    required this.scheme,
  });

  final String label;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? scheme.inverseSurface : scheme.surface;
    final fg = selected ? scheme.onInverseSurface : scheme.onSurface;
    final border = selected
        ? scheme.inverseSurface
        : isToday
            ? scheme.primary
            : scheme.outlineVariant;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

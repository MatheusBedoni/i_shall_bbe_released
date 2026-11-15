import 'package:flutter/material.dart';

import '../../domain/entities/budget_period.dart';

class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    super.key,
    required this.period,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final BudgetPeriod period;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = period == BudgetPeriod.now();
    return Row(
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            period.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
        if (!isCurrent)
          IconButton(
            tooltip: 'Mês atual',
            onPressed: onToday,
            icon: const Icon(Icons.today_outlined),
          ),
      ],
    );
  }
}

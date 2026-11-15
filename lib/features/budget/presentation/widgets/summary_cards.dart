import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/percent.dart';
import '../../domain/entities/allocation_rule.dart';
import '../../domain/entities/budget_summary.dart';

class SummaryCards extends StatelessWidget {
  const SummaryCards({super.key, required this.summary, required this.rule});

  final BudgetSummary summary;
  final AllocationRule rule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cards = [
      _CardData(
        title: 'Ganho Mensal',
        value: summary.income,
        note: 'Total de ganhos lançados',
        color: scheme.income,
      ),
      _CardData(
        title: 'Orçamento Despesas Fixas',
        value: summary.fixedExpenses.budget,
        note: '${Percent.format(rule.fixedExpensePct, decimals: 0)} do ganho',
      ),
      _CardData(
        title: 'Orçamento Investimentos',
        value: summary.investments.budget,
        note: '${Percent.format(rule.investmentPct, decimals: 0)} do ganho',
        color: scheme.investment,
      ),
      _CardData(
        title: 'Orçamento Despesas Recorrentes',
        value: summary.recurringExpenses.budget,
        note: 'Restante após fixas e investimentos',
      ),
      _CardData(
        title: 'Saldo Final',
        value: summary.finalBalance,
        note: 'Ganho menos tudo que foi lançado',
        color: summary.finalBalance < 0 ? scheme.loss : scheme.gain,
      ),
      _CardData(
        title: 'Gasto diário permitido',
        value: summary.dailyAllowance,
        note: summary.daysRemaining > 0
            ? '${summary.daysRemaining} dia(s) restante(s) no mês'
            : 'Mês encerrado',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 104,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, i) => _SummaryCard(data: cards[i]),
        );
      },
    );
  }
}

class _CardData {
  const _CardData({
    required this.title,
    required this.value,
    required this.note,
    this.color,
  });
  final String title;
  final double value;
  final String note;
  final Color? color;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});
  final _CardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              data.title,
              style: theme.textTheme.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              Money.format(data.value),
              style: theme.textTheme.titleLarge?.copyWith(
                color: data.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.note,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

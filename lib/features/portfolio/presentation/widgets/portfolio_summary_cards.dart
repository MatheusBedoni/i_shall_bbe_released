import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/percent.dart';
import '../../domain/entities/position.dart';

/// Cartões de resumo da carteira: patrimônio, investido, resultado, proventos.
class PortfolioSummaryCards extends StatelessWidget {
  const PortfolioSummaryCards({super.key, required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pnl = summary.totalUnrealizedPnl;
    final pnlColor = pnl == 0 ? null : (pnl > 0 ? scheme.gain : scheme.loss);
    final cards = [
      _CardData(
        title: 'Patrimônio',
        value: Money.format(summary.totalCurrentValue),
        note: '${summary.openPositions.length} posição(ões) aberta(s)',
        color: scheme.investment,
      ),
      _CardData(
        title: 'Total investido',
        value: Money.format(summary.totalInvested),
        note: 'Custo das posições abertas',
      ),
      _CardData(
        title: 'Resultado',
        value: Money.format(pnl),
        note: '${Percent.format(summary.totalUnrealizedPnlPercent)} sobre o investido',
        color: pnlColor,
      ),
      _CardData(
        title: 'Proventos',
        value: Money.format(summary.totalDividends),
        note: summary.totalRealizedPnl == 0
            ? 'Dividendos, JCP e rendimentos'
            : 'Lucro realizado: ${Money.format(summary.totalRealizedPnl)}',
        color: scheme.gain,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
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
  final String value;
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
            Text(data.title,
                style: theme.textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              data.value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: data.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(data.note,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

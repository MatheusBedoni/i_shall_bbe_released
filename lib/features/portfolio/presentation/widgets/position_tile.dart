import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/percent.dart';
import '../../domain/entities/position.dart';
import '../../domain/entities/quote.dart';

/// Linha de uma posição na lista da carteira.
class PositionTile extends StatelessWidget {
  const PositionTile({
    super.key,
    required this.position,
    required this.onTap,
    this.quote,
  });

  final Position position;
  final Quote? quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = position;
    final amountOnly = !p.asset.assetClass.hasMarketQuote;
    final pnl = p.unrealizedPnl;
    final pnlColor = pnl == 0 ? scheme.onSurfaceVariant : (pnl > 0 ? scheme.gain : scheme.loss);

    final String subtitle;
    if (amountOnly) {
      subtitle = '${p.asset.assetClass.label} · investido ${Money.format(p.invested)}';
    } else {
      final qty = p.quantity == p.quantity.roundToDouble()
          ? p.quantity.toStringAsFixed(0)
          : p.quantity.toStringAsFixed(4);
      final price = p.currentPrice;
      final priceText = price == null
          ? 'sem cotação'
          : '${Money.format(price)}${quote?.changePercent == null ? '' : ' (${_signed(quote!.changePercent!)})'}';
      subtitle = '$qty × PM ${Money.format(p.averagePrice)} · $priceText';
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHigh,
        child: Text(
          p.asset.ticker.length > 4 ? p.asset.ticker.substring(0, 4) : p.asset.ticker,
          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      title: Text('${p.asset.ticker} · ${p.asset.name}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Money.format(p.currentValue),
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (!amountOnly)
            Text(
              '${_signed(p.unrealizedPnlPercent)} · ${Money.format(pnl)}',
              style: theme.textTheme.bodySmall?.copyWith(color: pnlColor),
            ),
        ],
      ),
    );
  }

  static String _signed(double fraction) =>
      '${fraction > 0 ? '+' : ''}${Percent.format(fraction)}';
}

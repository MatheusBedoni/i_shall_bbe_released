import 'package:flutter/material.dart';

import '../../../../core/utils/percent.dart';
import '../../domain/entities/asset.dart';

/// Barra empilhada com a alocação da carteira por classe de ativo.
class AllocationBar extends StatelessWidget {
  const AllocationBar({super.key, required this.allocation});

  /// Fração por classe (soma 1).
  final Map<AssetClass, double> allocation;

  static const _order = AssetClass.values;

  Color _colorFor(ColorScheme scheme, AssetClass c) => switch (c) {
        AssetClass.stock => scheme.primary,
        AssetClass.fii => scheme.secondary,
        AssetClass.etf => scheme.tertiary,
        AssetClass.bdr => scheme.primaryContainer,
        AssetClass.fixedIncome => scheme.secondaryContainer,
        AssetClass.crypto => scheme.outline,
        AssetClass.other => scheme.surfaceContainerHighest,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = _order
        .where((c) => (allocation[c] ?? 0) > 0)
        .map((c) => MapEntry(c, allocation[c]!))
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alocação por classe', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (final e in entries)
                      Expanded(
                        flex: (e.value * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: _colorFor(scheme, e.key)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final e in entries)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colorFor(scheme, e.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${e.key.label} ${Percent.format(e.value, decimals: 0)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

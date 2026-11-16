import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/percent.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_transaction.dart';
import '../../domain/entities/dividend.dart';
import '../../domain/entities/position.dart';
import '../controllers/portfolio_controller.dart';
import '../widgets/asset_form_dialog.dart';
import '../widgets/dividend_form_dialog.dart';
import '../widgets/transaction_form_dialog.dart';

/// Detalhe de um ativo: posição, operações e proventos.
class AssetDetailPage extends StatelessWidget {
  const AssetDetailPage({
    super.key,
    required this.controller,
    required this.assetId,
  });

  final PortfolioController controller;
  final String assetId;

  PortfolioController get c => controller;

  Future<void> _editAsset(BuildContext context, Asset asset) async {
    final updated = await showAssetFormDialog(
      context,
      existing: asset,
      onSearch: c.suggestTickers,
    );
    if (updated == null) return;
    await c.editAsset(updated);
  }

  Future<void> _deleteAsset(BuildContext context, Asset asset) async {
    final confirmed = await _confirm(
      context,
      title: 'Excluir ${asset.ticker}?',
      body: 'Todas as operações e proventos deste ativo também serão apagados.',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await c.removeAsset(asset.id);
    if (ok && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _addTransaction(BuildContext context, Asset asset) async {
    final tx = await showTransactionFormDialog(
      context,
      assets: c.assets,
      fixedAsset: asset,
    );
    if (tx == null) return;
    await c.createTransaction(tx);
  }

  Future<void> _editTransaction(
    BuildContext context,
    Asset asset,
    AssetTransaction tx,
  ) async {
    final updated = await showTransactionFormDialog(
      context,
      assets: c.assets,
      fixedAsset: asset,
      existing: tx,
    );
    if (updated == null) return;
    await c.editTransaction(updated);
  }

  Future<void> _deleteTransaction(BuildContext context, AssetTransaction tx) async {
    final confirmed = await _confirm(
      context,
      title: 'Excluir operação?',
      body: '${tx.type.label} de ${Dates.short(tx.date)} será removida.',
    );
    if (confirmed) await c.removeTransaction(tx.id);
  }

  Future<void> _addDividend(BuildContext context, Asset asset) async {
    final d = await showDividendFormDialog(context, assets: c.assets, fixedAsset: asset);
    if (d == null) return;
    await c.createDividend(d);
  }

  Future<void> _editDividend(BuildContext context, Asset asset, Dividend d) async {
    final updated = await showDividendFormDialog(
      context,
      assets: c.assets,
      fixedAsset: asset,
      existing: d,
    );
    if (updated == null) return;
    await c.editDividend(updated);
  }

  Future<void> _deleteDividend(BuildContext context, Dividend d) async {
    final confirmed = await _confirm(
      context,
      title: 'Excluir provento?',
      body: '${d.type.label} de ${Money.format(d.amount)} será removido.',
    );
    if (confirmed) await c.removeDividend(d.id);
  }

  Future<bool> _confirm(BuildContext context,
      {required String title, required String body}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
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
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final asset = c.assetById(assetId);
        if (asset == null) {
          // Ativo removido enquanto a página estava aberta.
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Ativo não encontrado.')),
          );
        }
        final theme = Theme.of(context);
        final position = c.positionOf(asset.id);
        final txs = c.transactionsOf(asset.id);
        final divs = c.dividendsOf(asset.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(asset.ticker),
            actions: [
              IconButton(
                tooltip: 'Editar ativo',
                onPressed: () => _editAsset(context, asset),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Excluir ativo',
                onPressed: () => _deleteAsset(context, asset),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(asset.name, style: theme.textTheme.titleLarge),
              Text(asset.assetClass.label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              if (position != null) _PositionCard(position: position),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _addTransaction(context, asset),
                      icon: const Icon(Icons.add_chart),
                      label: const Text('Operação'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _addDividend(context, asset),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Provento'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Operações',
                emptyText: 'Nenhuma operação registrada.',
                children: [
                  for (final tx in txs)
                    _TxTile(
                      tx: tx,
                      amountOnly: !asset.assetClass.hasMarketQuote,
                      onEdit: () => _editTransaction(context, asset, tx),
                      onDelete: () => _deleteTransaction(context, tx),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Proventos',
                emptyText: 'Nenhum provento registrado.',
                children: [
                  for (final d in divs)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(d.type.label),
                      subtitle: Text(Dates.short(d.date)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(Money.format(d.amount),
                              style: TextStyle(color: theme.colorScheme.gain)),
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _editDividend(context, asset, d),
                          ),
                          IconButton(
                            tooltip: 'Excluir',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _deleteDividend(context, d),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.position});
  final Position position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = position;
    final amountOnly = !p.asset.assetClass.hasMarketQuote;
    final pnlColor = p.unrealizedPnl == 0
        ? null
        : (p.unrealizedPnl > 0 ? scheme.gain : scheme.loss);

    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(value,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Money.format(p.currentValue),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.investment,
              ),
            ),
            Text(
              p.isOpen ? 'Valor atual da posição' : 'Posição encerrada',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 20),
            if (!amountOnly) ...[
              row('Quantidade', p.quantity.toStringAsFixed(
                  p.quantity == p.quantity.roundToDouble() ? 0 : 4)),
              row('Preço médio', Money.format(p.averagePrice)),
              row(
                'Cotação',
                p.currentPrice == null ? 'sem cotação' : Money.format(p.currentPrice!),
              ),
            ],
            row('Investido', Money.format(p.invested)),
            if (!amountOnly)
              row(
                'Resultado',
                '${Money.format(p.unrealizedPnl)} (${Percent.format(p.unrealizedPnlPercent)})',
                color: pnlColor,
              ),
            if (p.realizedPnl != 0)
              row('Lucro realizado', Money.format(p.realizedPnl),
                  color: p.realizedPnl > 0 ? scheme.gain : scheme.loss),
            row('Proventos', Money.format(p.dividendsReceived), color: scheme.gain),
            row('Retorno total', Money.format(p.totalReturn),
                color: p.totalReturn == 0
                    ? null
                    : (p.totalReturn > 0 ? scheme.gain : scheme.loss)),
          ],
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    required this.tx,
    required this.amountOnly,
    required this.onEdit,
    required this.onDelete,
  });

  final AssetTransaction tx;
  final bool amountOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isBuy = tx.type == TransactionType.buy;
    final qty = tx.quantity == tx.quantity.roundToDouble()
        ? tx.quantity.toStringAsFixed(0)
        : tx.quantity.toStringAsFixed(4);
    final detail = amountOnly
        ? Dates.short(tx.date)
        : '${Dates.short(tx.date)} · $qty × ${Money.format(tx.unitPrice)}'
            '${tx.fees > 0 ? ' + taxas ${Money.format(tx.fees)}' : ''}';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isBuy ? Icons.arrow_downward : Icons.arrow_upward,
        color: isBuy ? scheme.investment : scheme.gain,
      ),
      title: Text(isBuy ? 'Aporte' : 'Venda'),
      subtitle: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Money.format(tx.netAmount)),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(emptyText, style: theme.textTheme.bodySmall),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

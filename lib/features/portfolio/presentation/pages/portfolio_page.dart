import 'package:flutter/material.dart';

import '../../../../core/utils/dates.dart';
import '../../domain/entities/asset.dart';
import '../controllers/portfolio_controller.dart';
import '../widgets/allocation_bar.dart';
import '../widgets/asset_form_dialog.dart';
import '../widgets/dividend_form_dialog.dart';
import '../widgets/portfolio_summary_cards.dart';
import '../widgets/position_tile.dart';
import '../widgets/transaction_form_dialog.dart';
import 'asset_detail_page.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key, required this.controller});

  final PortfolioController controller;

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  PortfolioController get c => widget.controller;
  bool _showClosed = false;

  @override
  void initState() {
    super.initState();
    c.start();
    c.addListener(_showTransientMessage);
  }

  @override
  void dispose() {
    c.removeListener(_showTransientMessage);
    super.dispose();
  }

  void _showTransientMessage() {
    final msg = c.consumeMessage();
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _newAsset() async {
    final asset = await showAssetFormDialog(context, onSearch: c.suggestTickers);
    if (asset == null) return;
    await c.createAsset(asset);
  }

  Future<void> _newTransaction() async {
    if (c.assets.isEmpty) {
      await _newAsset();
      if (c.assets.isEmpty) return;
    }
    if (!mounted) return;
    final tx = await showTransactionFormDialog(context, assets: c.assets);
    if (tx == null) return;
    await c.createTransaction(tx);
  }

  Future<void> _newDividend() async {
    if (c.assets.isEmpty) {
      await _newAsset();
      if (c.assets.isEmpty) return;
    }
    if (!mounted) return;
    final d = await showDividendFormDialog(context, assets: c.assets);
    if (d == null) return;
    await c.createDividend(d);
  }

  void _openAsset(Asset asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssetDetailPage(controller: c, assetId: asset.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteira'),
        actions: [
          ListenableBuilder(
            listenable: c,
            builder: (context, _) => IconButton(
              tooltip: 'Atualizar cotações',
              onPressed: c.refreshingQuotes ? null : () => c.refreshQuotes(force: true),
              icon: c.refreshingQuotes
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
          PopupMenuButton<_AddAction>(
            tooltip: 'Adicionar',
            icon: const Icon(Icons.add),
            onSelected: (a) => switch (a) {
              _AddAction.asset => _newAsset(),
              _AddAction.transaction => _newTransaction(),
              _AddAction.dividend => _newDividend(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _AddAction.transaction,
                child: ListTile(
                  leading: Icon(Icons.add_chart),
                  title: Text('Aporte ou venda'),
                ),
              ),
              PopupMenuItem(
                value: _AddAction.dividend,
                child: ListTile(
                  leading: Icon(Icons.payments_outlined),
                  title: Text('Provento'),
                ),
              ),
              PopupMenuItem(
                value: _AddAction.asset,
                child: ListTile(
                  leading: Icon(Icons.playlist_add),
                  title: Text('Novo ativo'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final summary = c.summary;
          if (c.loading && summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final open = c.openPositions;
          final closed = c.closedPositions;
          return RefreshIndicator(
            onRefresh: () => c.refreshQuotes(force: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      c.error!,
                      style: TextStyle(color: scheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (c.assets.isEmpty)
                  _EmptyState(onAddAsset: _newAsset)
                else if (summary != null) ...[
                  PortfolioSummaryCards(summary: summary),
                  const SizedBox(height: 8),
                  _QuoteStatus(
                    updatedAt: c.quotesUpdatedAt,
                    error: c.quoteError,
                    refreshing: c.refreshingQuotes,
                  ),
                  const SizedBox(height: 8),
                  AllocationBar(allocation: summary.allocationByClass),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text('Posições', style: theme.textTheme.titleMedium),
                        ),
                        if (open.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Nenhuma posição aberta. Registre um aporte para começar.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        for (final p in open)
                          PositionTile(
                            position: p,
                            quote: c.quoteOf(p.asset),
                            onTap: () => _openAsset(p.asset),
                          ),
                        if (closed.isNotEmpty) ...[
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            title: Text(
                              '${closed.length} ativo(s) sem posição',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Icon(
                              _showClosed ? Icons.expand_less : Icons.expand_more,
                            ),
                            onTap: () => setState(() => _showClosed = !_showClosed),
                          ),
                          if (_showClosed)
                            for (final p in closed)
                              ListTile(
                                dense: true,
                                title: Text('${p.asset.ticker} · ${p.asset.name}'),
                                subtitle: Text(p.asset.assetClass.label),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openAsset(p.asset),
                              ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newTransaction,
        icon: const Icon(Icons.add),
        label: const Text('Aporte'),
      ),
    );
  }
}

enum _AddAction { asset, transaction, dividend }

class _QuoteStatus extends StatelessWidget {
  const _QuoteStatus({
    required this.updatedAt,
    required this.error,
    required this.refreshing,
  });

  final DateTime? updatedAt;
  final String? error;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final String text;
    Color? color;
    if (refreshing) {
      text = 'Buscando cotações na brapi.dev…';
    } else if (error != null) {
      text = error!;
      color = scheme.error;
    } else if (updatedAt != null) {
      text = 'Cotações brapi.dev · ${Dates.withTime(updatedAt!)}';
    } else {
      text = 'Ativos sem cotação valem o custo de aquisição.';
    }
    return Row(
      children: [
        Icon(Icons.show_chart, size: 16, color: color ?? scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddAsset});
  final VoidCallback onAddAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.pie_chart_outline, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Sua carteira está vazia', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Cadastre os ativos que você já tem (ações, FIIs, ETFs, renda fixa…). '
              'Depois, cada aporte feito no mês aparece automaticamente no '
              'envelope de investimentos do orçamento.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddAsset,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Cadastrar primeiro ativo'),
            ),
          ],
        ),
      ),
    );
  }
}

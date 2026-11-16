import 'package:flutter/material.dart';

import '../../../portfolio/domain/entities/contribution.dart';
import '../../../portfolio/presentation/controllers/portfolio_controller.dart';
import '../../../portfolio/presentation/widgets/asset_form_dialog.dart';
import '../../../portfolio/presentation/widgets/transaction_form_dialog.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/entry_type.dart';
import '../controllers/budget_controller.dart';
import '../widgets/entry_form_dialog.dart';
import '../widgets/entry_section.dart';
import '../widgets/investment_section.dart';
import '../widgets/period_selector.dart';
import '../widgets/summary_cards.dart';
import 'allocation_settings_page.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({
    super.key,
    required this.controller,
    required this.portfolio,
  });

  final BudgetController controller;

  /// Usado para registrar aportes a partir do orçamento.
  final PortfolioController portfolio;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  BudgetController get c => widget.controller;
  PortfolioController get p => widget.portfolio;

  @override
  void initState() {
    super.initState();
    c.start();
    p.start();
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------------------ Lançamentos

  Future<void> _add(EntryType type) async {
    final result = await showEntryFormDialog(context, type: type);
    if (result == null) return;
    await c.add(
      type: result.type,
      description: result.description,
      amount: result.amount,
    );
  }

  Future<void> _edit(BudgetEntry entry) async {
    final result =
        await showEntryFormDialog(context, type: entry.type, existing: entry);
    if (result == null) return;
    await c.update(entry.copyWith(
      type: result.type,
      description: result.description,
      amount: result.amount,
    ));
  }

  Future<void> _delete(BudgetEntry entry) async {
    final confirmed = await _confirm(
      'Excluir lançamento?',
      '"${entry.description}" será removido.',
    );
    if (confirmed) await c.remove(entry.id);
  }

  // ---------------------------------------------------------------- Aportes

  Future<void> _addContribution() async {
    if (p.assets.isEmpty) {
      // Sem ativos cadastrados: cadastra o primeiro antes do aporte.
      final asset = await showAssetFormDialog(context, onSearch: p.suggestTickers);
      if (asset == null) return;
      final ok = await p.createAsset(asset);
      if (!ok) {
        _snack(p.error ?? 'Não foi possível cadastrar o ativo.');
        return;
      }
      // Aguarda o stream entregar o novo ativo.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (p.assets.isEmpty) return;
    }
    if (!mounted) return;
    final tx = await showTransactionFormDialog(
      context,
      assets: p.assets,
      initialDate: c.suggestedContributionDate(),
      allowSell: false,
    );
    if (tx == null) return;
    final ok = await p.createTransaction(tx);
    if (!ok) _snack(p.error ?? 'Não foi possível registrar o aporte.');
  }

  Future<void> _editContribution(Contribution contribution) async {
    final tx = await showTransactionFormDialog(
      context,
      assets: p.assets,
      fixedAsset: contribution.asset,
      existing: contribution.transaction,
      allowSell: false,
    );
    if (tx == null) return;
    final ok = await p.editTransaction(tx);
    if (!ok) _snack(p.error ?? 'Não foi possível salvar o aporte.');
  }

  Future<void> _deleteContribution(Contribution contribution) async {
    final confirmed = await _confirm(
      'Excluir aporte?',
      'O aporte em ${contribution.asset.ticker} será removido da carteira também.',
    );
    if (!confirmed) return;
    final ok = await p.removeTransaction(contribution.id);
    if (!ok) _snack(p.error ?? 'Não foi possível excluir o aporte.');
  }

  Future<bool> _confirm(String title, String body) async {
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AllocationSettingsPage(initial: c.rule, onSave: c.saveRule),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamento'),
        actions: [
          IconButton(
            tooltip: 'Copiar mês anterior',
            onPressed: c.copyFromPreviousMonth,
            icon: const Icon(Icons.content_copy_outlined),
          ),
          IconButton(
            tooltip: 'Regra de orçamento',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([c, p]),
        builder: (context, _) {
          final summary = c.summary;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PeriodSelector(
                period: c.period,
                onSelect: c.selectPeriod,
                onToday: c.goToCurrentMonth,
              ),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    c.error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (c.loading && summary == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (summary != null) ...[
                const SizedBox(height: 8),
                SummaryCards(summary: summary, rule: c.rule),
                const SizedBox(height: 16),
                for (final type in EntryType.values) ...[
                  if (type == EntryType.investment)
                    InvestmentSection(
                      envelope: summary.investments,
                      contributions: c.contributions,
                      entries: c.entriesOf(type),
                      onAddContribution: _addContribution,
                      onEditContribution: _editContribution,
                      onDeleteContribution: _deleteContribution,
                      onAddEntry: () => _add(type),
                      onEditEntry: _edit,
                      onDeleteEntry: _delete,
                    )
                  else
                    EntrySection(
                      type: type,
                      entries: c.entriesOf(type),
                      envelope: type == EntryType.income ? null : summary.envelope(type),
                      onAdd: () => _add(type),
                      onEdit: _edit,
                      onDelete: _delete,
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

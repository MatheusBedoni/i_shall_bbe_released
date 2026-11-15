import 'package:flutter/material.dart';

import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/entry_type.dart';
import '../controllers/budget_controller.dart';
import '../widgets/entry_form_dialog.dart';
import '../widgets/entry_section.dart';
import '../widgets/period_selector.dart';
import '../widgets/summary_cards.dart';
import 'allocation_settings_page.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key, required this.controller});

  final BudgetController controller;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  BudgetController get c => widget.controller;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text('"${entry.description}" será removido.'),
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
    if (confirmed == true) await c.remove(entry.id);
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
        listenable: c,
        builder: (context, _) {
          final summary = c.summary;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PeriodSelector(
                period: c.period,
                onPrevious: c.previousMonth,
                onNext: c.nextMonth,
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

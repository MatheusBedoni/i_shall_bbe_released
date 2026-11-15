import 'package:flutter/material.dart';

import '../../../../core/utils/percent.dart';
import '../../domain/entities/allocation_rule.dart';

/// Permite ao usuário definir os percentuais dos envelopes.
class AllocationSettingsPage extends StatefulWidget {
  const AllocationSettingsPage({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final AllocationRule initial;
  final Future<bool> Function(AllocationRule rule) onSave;

  @override
  State<AllocationSettingsPage> createState() => _AllocationSettingsPageState();
}

class _AllocationSettingsPageState extends State<AllocationSettingsPage> {
  late double _fixed = widget.initial.fixedExpensePct;
  late double _investment = widget.initial.investmentPct;
  bool _saving = false;

  AllocationRule get _rule =>
      AllocationRule(fixedExpensePct: _fixed, investmentPct: _investment);

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.onSave(_rule);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _rule.validate();
    return Scaffold(
      appBar: AppBar(title: const Text('Regra de orçamento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'A distribuição é em cascata e se ajusta todo mês ao que foi '
            'realmente gasto: o que não for usado em despesas fixas ou '
            'investimentos sobra para as despesas recorrentes.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _PercentSlider(
            label: 'Despesas fixas',
            hint: 'do ganho mensal',
            value: _fixed,
            onChanged: (v) => setState(() => _fixed = v),
          ),
          _PercentSlider(
            label: 'Investimentos',
            hint: 'do que sobrar após as despesas fixas',
            value: _investment,
            onChanged: (v) => setState(() => _investment = v),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Se tudo for gasto exatamente no orçamento:',
                      style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  _NominalRow('Despesas fixas', _fixed),
                  _NominalRow('Investimentos', _rule.nominalInvestmentPct),
                  _NominalRow('Despesas recorrentes', _rule.nominalRecurringPct),
                ],
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error.message, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: error == null && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _fixed = AllocationRule.defaultRule.fixedExpensePct;
              _investment = AllocationRule.defaultRule.investmentPct;
            }),
            child: const Text('Restaurar padrão (33% / 33%)'),
          ),
        ],
      ),
    );
  }
}

class _NominalRow extends StatelessWidget {
  const _NominalRow(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(Percent.format(value, decimals: 0)),
        ],
      ),
    );
  }
}

class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String hint;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(hint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text(Percent.format(value, decimals: 0),
                style: theme.textTheme.titleMedium),
          ],
        ),
        Slider(
          value: value,
          divisions: 100,
          label: Percent.format(value, decimals: 0),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

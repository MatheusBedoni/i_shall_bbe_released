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
            'Defina quanto do seu ganho mensal vai para cada envelope. '
            'O que sobrar é o orçamento de despesas recorrentes.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _PercentSlider(
            label: 'Despesas fixas',
            value: _fixed,
            onChanged: (v) => setState(() => _fixed = v),
          ),
          _PercentSlider(
            label: 'Investimentos',
            value: _investment,
            onChanged: (v) => setState(() => _investment = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Despesas recorrentes (restante)'),
            trailing: Text(
              Percent.format(_rule.recurringExpensePct, decimals: 0),
              style: theme.textTheme.titleMedium,
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

class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(Percent.format(value, decimals: 0)),
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

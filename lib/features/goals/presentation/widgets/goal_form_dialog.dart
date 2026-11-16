import 'package:flutter/material.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../portfolio/domain/entities/position.dart';
import '../../domain/entities/goal.dart';

/// Abre o formulário para criar ([existing] == null) ou editar uma meta.
///
/// [positions] são as posições atuais da carteira, oferecidas para vínculo:
/// o valor de mercado dos ativos escolhidos passa a compor o saldo da meta.
Future<Goal?> showGoalFormDialog(
  BuildContext context, {
  Goal? existing,
  required List<Position> positions,
}) {
  return showDialog<Goal>(
    context: context,
    builder: (_) => _GoalFormDialog(existing: existing, positions: positions),
  );
}

class _GoalFormDialog extends StatefulWidget {
  const _GoalFormDialog({required this.positions, this.existing});
  final Goal? existing;
  final List<Position> positions;

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _target =
      TextEditingController(text: _fmt(widget.existing?.targetAmount));
  late final _current =
      TextEditingController(text: _fmtOrEmpty(widget.existing?.currentAmount));
  late final _monthly =
      TextEditingController(text: _fmt(widget.existing?.monthlyContribution));
  late final _rate = TextEditingController(
    text: widget.existing == null
        ? '10'
        : _fmt(widget.existing!.annualRate * 100),
  );
  late DateTime? _deadline = widget.existing?.deadline;
  late final List<String> _linked = List.of(widget.existing?.linkedAssetIds ?? const []);

  late final List<Position> _options = widget.positions.toList()
    ..sort((a, b) => a.asset.ticker.compareTo(b.asset.ticker));

  static String _fmt(double? v) => v == null
      ? ''
      : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',');

  static String _fmtOrEmpty(double? v) => v == null || v == 0 ? '' : _fmt(v);

  /// Ids vinculados que não estão entre as posições (ativo apagado ou
  /// carteira ainda carregando). São preservados ao salvar.
  List<String> get _unknownLinked {
    final known = {for (final p in _options) p.asset.id};
    return _linked.where((id) => !known.contains(id)).toList();
  }

  double get _linkedValue => _options
      .where((p) => _linked.contains(p.asset.id))
      .fold(0.0, (s, p) => s + p.currentValue);

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _current.dispose();
    _monthly.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 60),
      helpText: 'Prazo da meta',
    );
    if (picked != null) setState(() => _deadline = Dates.dateOnly(picked));
  }

  void _toggle(String assetId, bool selected) {
    setState(() {
      if (selected) {
        if (!_linked.contains(assetId)) _linked.add(assetId);
      } else {
        _linked.remove(assetId);
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final rate = (Money.parse(_rate.text) ?? 0) / 100;
    Navigator.of(context).pop(Goal(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      targetAmount: Money.parse(_target.text)!,
      currentAmount:
          _current.text.trim().isEmpty ? 0 : (Money.parse(_current.text) ?? 0),
      monthlyContribution:
          _monthly.text.trim().isEmpty ? 0 : (Money.parse(_monthly.text) ?? 0),
      annualRate: rate,
      deadline: _deadline,
      linkedAssetIds: List.unmodifiable(_linked),
    ));
  }

  String? _nonNegative(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final p = Money.parse(v);
    return (p == null || p < 0) ? 'Valor inválido' : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isEdit = widget.existing != null;
    final hasLinks = _linked.isNotEmpty;
    final manual = Money.parse(_current.text) ?? 0;
    final unknown = _unknownLinked;

    return AlertDialog(
      title: Text(isEdit ? 'Editar meta' : 'Nova meta'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: !isEdit,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Ex.: Reserva de emergência, Viagem',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Dê um nome à meta' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor da meta',
                    prefixText: r'R$ ',
                  ),
                  validator: (v) {
                    final p = v == null ? null : Money.parse(v);
                    return (p == null || p <= 0) ? 'Informe um valor maior que zero' : null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _deadline == null
                        ? 'Prazo (opcional)'
                        : 'Prazo: ${Dates.short(_deadline!)}',
                  ),
                ),
                if (_deadline != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _deadline = null),
                      child: const Text('Remover prazo'),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _monthly,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Aporte mensal',
                          prefixText: r'R$ ',
                        ),
                        validator: _nonNegative,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rate,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Rentabilidade a.a.',
                          suffixText: '%',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final p = Money.parse(v);
                          return (p == null || p <= -100) ? 'Inválida' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Vincular investimentos', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  'O valor atual dos ativos escolhidos passa a compor o saldo '
                  'da meta e acompanha aportes e cotações automaticamente.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (_options.isEmpty)
                  Text(
                    'Nenhum ativo na carteira ainda. Cadastre ativos na aba '
                    'Carteira para vinculá-los aqui.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final p in _options)
                        FilterChip(
                          label: Text(
                            '${p.asset.ticker} · ${Money.compact(p.currentValue)}',
                          ),
                          selected: _linked.contains(p.asset.id),
                          onSelected: (s) => _toggle(p.asset.id, s),
                        ),
                    ],
                  ),
                if (unknown.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${unknown.length} ativo(s) vinculado(s) não '
                            'encontrado(s) na carteira.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _linked.removeWhere(unknown.contains),
                          ),
                          child: const Text('Desvincular'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _current,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: hasLinks
                        ? 'Saldo fora da carteira (opcional)'
                        : 'Saldo atual (opcional)',
                    prefixText: r'R$ ',
                    helperText: hasLinks
                        ? 'Dinheiro guardado em outro lugar, somado aos ativos.'
                        : null,
                  ),
                  validator: _nonNegative,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (hasLinks) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Saldo atual: ${Money.format(manual + _linkedValue)} '
                    '(carteira ${Money.format(_linkedValue)} + fora ${Money.format(manual)})',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.end,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Salvar' : 'Criar meta'),
        ),
      ],
    );
  }
}

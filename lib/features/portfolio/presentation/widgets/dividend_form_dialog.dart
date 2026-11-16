import 'package:flutter/material.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/dividend.dart';

/// Abre o formulário de provento (dividendo, JCP, rendimento).
Future<Dividend?> showDividendFormDialog(
  BuildContext context, {
  required List<Asset> assets,
  Asset? fixedAsset,
  Dividend? existing,
}) {
  return showDialog<Dividend>(
    context: context,
    builder: (_) => _DividendFormDialog(
      assets: assets,
      fixedAsset: fixedAsset,
      existing: existing,
    ),
  );
}

class _DividendFormDialog extends StatefulWidget {
  const _DividendFormDialog({
    required this.assets,
    this.fixedAsset,
    this.existing,
  });

  final List<Asset> assets;
  final Asset? fixedAsset;
  final Dividend? existing;

  @override
  State<_DividendFormDialog> createState() => _DividendFormDialogState();
}

class _DividendFormDialogState extends State<_DividendFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late Asset? _asset = widget.fixedAsset ??
      _find(widget.existing?.assetId) ??
      (widget.assets.length == 1 ? widget.assets.first : null);
  late DividendType _type = widget.existing?.type ??
      (_asset?.assetClass == AssetClass.fii ? DividendType.income : DividendType.dividend);
  late DateTime _date = Dates.dateOnly(widget.existing?.date ?? DateTime.now());
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.amount.toStringAsFixed(2).replaceAll('.', ','),
  );

  Asset? _find(String? id) {
    if (id == null) return null;
    for (final a in widget.assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = Dates.dateOnly(picked));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final asset = _asset;
    if (asset == null) return;
    Navigator.of(context).pop(Dividend(
      id: widget.existing?.id ?? '',
      assetId: asset.id,
      type: _type,
      amount: Money.parse(_amount.text)!,
      date: _date,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Editar provento' : 'Novo provento'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.fixedAsset != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(widget.fixedAsset!.ticker),
                  subtitle: Text(widget.fixedAsset!.name),
                )
              else
                DropdownButtonFormField<Asset>(
                  initialValue: _asset,
                  decoration: const InputDecoration(labelText: 'Ativo'),
                  items: widget.assets
                      .map((a) => DropdownMenuItem(
                            value: a,
                            child: Text('${a.ticker} · ${a.name}',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (a) => setState(() => _asset = a),
                  validator: (a) => a == null ? 'Selecione um ativo' : null,
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DividendType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: DividendType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (t) => setState(() => _type = t ?? _type),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                autofocus: !isEdit,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor líquido recebido',
                  prefixText: r'R$ ',
                ),
                validator: (v) {
                  final parsed = v == null ? null : Money.parse(v);
                  return (parsed == null || parsed <= 0)
                      ? 'Informe um valor maior que zero'
                      : null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text('Data: ${Dates.short(_date)}'),
              ),
            ],
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
          child: Text(isEdit ? 'Salvar' : 'Registrar'),
        ),
      ],
    );
  }
}

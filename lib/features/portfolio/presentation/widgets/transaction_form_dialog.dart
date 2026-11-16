import 'package:flutter/material.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/asset_transaction.dart';

/// Abre o formulário de aporte/venda.
///
/// - [assets]: ativos disponíveis para escolha.
/// - [fixedAsset]: quando informado, o ativo não pode ser trocado.
/// - [existing]: transação a editar.
/// - [initialDate]: data sugerida para uma nova transação.
/// - [allowSell]: mostra a opção de venda (o orçamento só lança aportes).
///
/// Para ativos sem cotação (renda fixa, outros) o formulário pede apenas o
/// valor: a transação é gravada com `quantity = valor` e `unitPrice = 1`, o
/// que mantém o custo correto e permite resgates parciais.
Future<AssetTransaction?> showTransactionFormDialog(
  BuildContext context, {
  required List<Asset> assets,
  Asset? fixedAsset,
  AssetTransaction? existing,
  DateTime? initialDate,
  bool allowSell = true,
}) {
  return showDialog<AssetTransaction>(
    context: context,
    builder: (_) => _TransactionFormDialog(
      assets: assets,
      fixedAsset: fixedAsset,
      existing: existing,
      initialDate: initialDate,
      allowSell: allowSell,
    ),
  );
}

class _TransactionFormDialog extends StatefulWidget {
  const _TransactionFormDialog({
    required this.assets,
    required this.allowSell,
    this.fixedAsset,
    this.existing,
    this.initialDate,
  });

  final List<Asset> assets;
  final Asset? fixedAsset;
  final AssetTransaction? existing;
  final DateTime? initialDate;
  final bool allowSell;

  @override
  State<_TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<_TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late Asset? _asset = widget.fixedAsset ??
      _find(widget.existing?.assetId) ??
      (widget.assets.length == 1 ? widget.assets.first : null);
  late TransactionType _type = widget.existing?.type ?? TransactionType.buy;
  late DateTime _date = Dates.dateOnly(
    widget.existing?.date ?? widget.initialDate ?? DateTime.now(),
  );

  late final _quantity = TextEditingController(
    text: _fmt(widget.existing?.quantity),
  );
  late final _price = TextEditingController(
    text: _fmt(widget.existing?.unitPrice),
  );
  late final _fees = TextEditingController(
    text: widget.existing == null || widget.existing!.fees == 0
        ? ''
        : _fmt(widget.existing!.fees),
  );
  late final _amount = TextEditingController(
    text: _fmt(widget.existing?.grossAmount),
  );

  bool get _amountOnly => !(_asset?.assetClass.hasMarketQuote ?? true);

  Asset? _find(String? id) {
    if (id == null) return null;
    for (final a in widget.assets) {
      if (a.id == id) return a;
    }
    return null;
  }

  static String _fmt(double? v) =>
      v == null ? '' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2).replaceAll('.', ',');

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _fees.dispose();
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

    final double quantity;
    final double unitPrice;
    final double fees;
    if (_amountOnly) {
      quantity = Money.parse(_amount.text)!;
      unitPrice = 1;
      fees = 0;
    } else {
      quantity = Money.parse(_quantity.text)!;
      unitPrice = Money.parse(_price.text)!;
      fees = _fees.text.trim().isEmpty ? 0 : (Money.parse(_fees.text) ?? 0);
    }

    Navigator.of(context).pop(AssetTransaction(
      id: widget.existing?.id ?? '',
      assetId: asset.id,
      type: _type,
      quantity: quantity,
      unitPrice: unitPrice,
      fees: fees,
      date: _date,
    ));
  }

  String? _positive(String? v, String msg) {
    final parsed = v == null ? null : Money.parse(v);
    return (parsed == null || parsed <= 0) ? msg : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    final title = isEdit
        ? 'Editar operação'
        : _type == TransactionType.buy
            ? 'Novo aporte'
            : 'Nova venda';

    final total = _amountOnly
        ? Money.parse(_amount.text)
        : () {
            final q = Money.parse(_quantity.text);
            final p = Money.parse(_price.text);
            if (q == null || p == null) return null;
            final f = Money.parse(_fees.text) ?? 0;
            return _type == TransactionType.buy ? q * p + f : q * p - f;
          }();

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                if (widget.allowSell) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.buy,
                        label: Text('Aporte'),
                        icon: Icon(Icons.add_circle_outline),
                      ),
                      ButtonSegment(
                        value: TransactionType.sell,
                        label: Text('Venda'),
                        icon: Icon(Icons.remove_circle_outline),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                ],
                const SizedBox(height: 12),
                if (_amountOnly)
                  TextFormField(
                    controller: _amount,
                    autofocus: !isEdit,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      prefixText: r'R$ ',
                    ),
                    validator: (v) => _positive(v, 'Informe um valor maior que zero'),
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _submit(),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantity,
                          autofocus: !isEdit,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Quantidade'),
                          validator: (v) => _positive(v, 'Maior que zero'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Preço unitário',
                            prefixText: r'R$ ',
                          ),
                          validator: (v) => _positive(v, 'Maior que zero'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fees,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Taxas e corretagem (opcional)',
                      prefixText: r'R$ ',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final p = Money.parse(v);
                      return (p == null || p < 0) ? 'Valor inválido' : null;
                    },
                    onChanged: (_) => setState(() {}),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text('Data: ${Dates.short(_date)}'),
                ),
                if (total != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${_type == TransactionType.buy ? 'Custo total' : 'Valor líquido'}: '
                    '${Money.format(total)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
          child: Text(isEdit ? 'Salvar' : 'Registrar'),
        ),
      ],
    );
  }
}

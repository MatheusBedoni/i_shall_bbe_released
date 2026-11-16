import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/asset.dart';
import '../../domain/entities/ticker_suggestion.dart';

typedef TickerSearch = Future<List<TickerSuggestion>> Function(String query);

/// Abre o diálogo para cadastrar ([existing] == null) ou editar um ativo.
/// Com [onSearch], o campo de código sugere ativos reais da B3.
Future<Asset?> showAssetFormDialog(
  BuildContext context, {
  Asset? existing,
  TickerSearch? onSearch,
}) {
  return showDialog<Asset>(
    context: context,
    builder: (_) => _AssetFormDialog(existing: existing, onSearch: onSearch),
  );
}

class _AssetFormDialog extends StatefulWidget {
  const _AssetFormDialog({this.existing, this.onSearch});
  final Asset? existing;
  final TickerSearch? onSearch;

  @override
  State<_AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<_AssetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _ticker = TextEditingController(text: widget.existing?.ticker ?? '');
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late AssetClass _class = widget.existing?.assetClass ?? AssetClass.stock;

  List<TickerSuggestion> _suggestions = const [];
  bool _searching = false;
  Timer? _debounce;
  int _searchSeq = 0;

  bool get _canSearch => widget.onSearch != null && _class.hasMarketQuote;

  @override
  void dispose() {
    _debounce?.cancel();
    _ticker.dispose();
    _name.dispose();
    super.dispose();
  }

  void _onTickerChanged(String value) {
    if (!_canSearch) return;
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    final seq = ++_searchSeq;
    setState(() => _searching = true);
    final list = await widget.onSearch!(q);
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _searching = false;
      _suggestions = list;
    });
  }

  void _pick(TickerSuggestion s) {
    setState(() {
      _ticker.text = s.ticker;
      _name.text = s.name;
      _class = s.assetClass;
      _suggestions = const [];
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(Asset(
      id: widget.existing?.id ?? '',
      ticker: _ticker.text.trim().toUpperCase(),
      name: _name.text.trim(),
      assetClass: _class,
      currency: widget.existing?.currency ?? 'BRL',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Editar ativo' : 'Novo ativo'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<AssetClass>(
                  initialValue: _class,
                  decoration: const InputDecoration(labelText: 'Classe'),
                  items: AssetClass.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (c) => setState(() {
                    _class = c ?? _class;
                    _suggestions = const [];
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ticker,
                  autofocus: !isEdit,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: _class.hasMarketQuote ? 'Código (ticker)' : 'Código',
                    hintText: _class.hasMarketQuote ? 'Ex.: PETR4, HGLG11' : 'Ex.: TESOURO-SELIC-2029',
                    helperText: _canSearch ? 'Digite para buscar na B3' : null,
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: _onTickerChanged,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o código' : null,
                ),
                if (_suggestions.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in _suggestions.take(6))
                          ListTile(
                            dense: true,
                            title: Text(s.ticker),
                            subtitle: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              s.lastPrice == null
                                  ? s.assetClass.label
                                  : Money.format(s.lastPrice!),
                              style: theme.textTheme.bodySmall,
                            ),
                            onTap: () => _pick(s),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
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
          child: Text(isEdit ? 'Salvar' : 'Cadastrar'),
        ),
      ],
    );
  }
}

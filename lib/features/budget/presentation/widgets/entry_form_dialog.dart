import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/budget_entry.dart';
import '../../domain/entities/entry_type.dart';

/// Resultado do formulário de lançamento.
final class EntryFormResult {
  const EntryFormResult({
    required this.type,
    required this.description,
    required this.amount,
  });
  final EntryType type;
  final String description;
  final double amount;
}

/// Abre o diálogo para criar ([existing] == null) ou editar um lançamento.
Future<EntryFormResult?> showEntryFormDialog(
  BuildContext context, {
  required EntryType type,
  BudgetEntry? existing,
}) {
  return showDialog<EntryFormResult>(
    context: context,
    builder: (_) => _EntryFormDialog(type: type, existing: existing),
  );
}

class _EntryFormDialog extends StatefulWidget {
  const _EntryFormDialog({required this.type, this.existing});
  final EntryType type;
  final BudgetEntry? existing;

  @override
  State<_EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends State<_EntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _description =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.amount.toStringAsFixed(2).replaceAll('.', ','),
  );
  late EntryType _type = widget.existing?.type ?? widget.type;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      EntryFormResult(
        type: _type,
        description: _description.text.trim(),
        amount: Money.parse(_amount.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Editar lançamento' : 'Novo lançamento'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<EntryType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: EntryType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (t) => setState(() => _type = t ?? _type),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descrição'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe uma descrição' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: r'R$ ',
              ),
              validator: (v) {
                final parsed = v == null ? null : Money.parse(v);
                if (parsed == null || parsed <= 0) return 'Informe um valor maior que zero';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: Text(isEdit ? 'Salvar' : 'Adicionar')),
      ],
    );
  }
}

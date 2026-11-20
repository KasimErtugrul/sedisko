import 'package:flutter/material.dart';

/// "Ödünç ver" girişi diyalogu (1.18.0).
///
/// Kişi adı zorunludur; not isteğe bağlıdır. Tarih denetleyici tarafından
/// eklenir (diyalog tarih sormaz). Dönen değer: onaylanırsa
/// `(kişi, not)` — not boşsa boş string gelir, çağıran kırpıp
/// temizler; vazgeçilirse `null`.
Future<(String person, String note)?> showLendDialog(
  BuildContext context, {
  String? initialPerson,
  String? note,
}) {
  return showDialog<(String, String)>(
    context: context,
    builder: (dialogContext) => _LendDialog(
      initialPerson: initialPerson,
      initialNote: note,
    ),
  );
}

class _LendDialog extends StatefulWidget {
  const _LendDialog({this.initialPerson, this.initialNote});

  final String? initialPerson;
  final String? initialNote;

  @override
  State<_LendDialog> createState() => _LendDialogState();
}

class _LendDialogState extends State<_LendDialog> {
  late final TextEditingController _personCtrl =
      TextEditingController(text: widget.initialPerson ?? '');
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.initialNote ?? '');

  String? _error;

  @override
  void dispose() {
    _personCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String? _validate(String raw) {
    if (raw.trim().isEmpty) return 'Kişi adı boş olamaz';
    return null;
  }

  void _submit() {
    final error = _validate(_personCtrl.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      (_personCtrl.text.trim(), _noteCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ödünç ver'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('lend-person-field'),
            controller: _personCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Kişi *',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('lend-note-field'),
            controller: _noteCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Not (isteğe bağlı)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        // Kişi boşken düğme pasiftir; boş girdi hiç onaylanamaz.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _personCtrl,
          builder: (context, value, _) {
            final enabled = value.text.trim().isNotEmpty;
            return FilledButton(
              key: const Key('lend-submit-button'),
              onPressed: enabled ? _submit : null,
              child: const Text('Ödünç ver'),
            );
          },
        ),
      ],
    );
  }
}

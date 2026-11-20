import 'package:flutter/material.dart';

import 'reminder_date_row.dart';

/// "Ödünç ver" girişi diyalogu (1.18.0).
///
/// Kişi adı zorunludur; not ve iade hatırlatma günü isteğe bağlıdır (keşke
/// 34, 1.26.0: "ne zaman geri isteyeceğim benim aklımda kalıyor" — hızlı
/// çiplerle ya da takvimden gün seçilir; seçilmezse davranış eskisi gibidir).
/// Tarih denetleyici tarafından eklenir (diyalog tarih sormaz). Dönen değer:
/// onaylanırsa `(kişi, not, iade günü)` — not boşsa boş string gelir,
/// çağıran kırpıp temizler; gün `null` ise hatırlatma kurulmaz;
/// vazgeçilirse `null`.
Future<(String person, String note, DateTime? dueAt)?> showLendDialog(
  BuildContext context, {
  String? initialPerson,
  String? note,
  DateTime? initialDueAt,
}) {
  return showDialog<(String, String, DateTime?)>(
    context: context,
    builder: (dialogContext) => _LendDialog(
      initialPerson: initialPerson,
      initialNote: note,
      initialDueAt: initialDueAt,
    ),
  );
}

class _LendDialog extends StatefulWidget {
  const _LendDialog({
    this.initialPerson,
    this.initialNote,
    this.initialDueAt,
  });

  final String? initialPerson;
  final String? initialNote;
  final DateTime? initialDueAt;

  @override
  State<_LendDialog> createState() => _LendDialogState();
}

class _LendDialogState extends State<_LendDialog> {
  late final TextEditingController _personCtrl =
      TextEditingController(text: widget.initialPerson ?? '');
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.initialNote ?? '');

  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    _dueAt = widget.initialDueAt;
  }

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
      (_personCtrl.text.trim(), _noteCtrl.text.trim(), _dueAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ödünç ver'),
      content: SingleChildScrollView(
        child: Column(
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
          const SizedBox(height: 16),
          // Keşke 34 (1.26.0): iade hatırlatması — çiplerle ya da takvimden
          // gün seçilir; seçilmeyen kayıt hatırlatmasız yaşar (eski davranış).
          ReminderDateRow(
            label: 'İade hatırlatması (isteğe bağlı)',
            selected: _dueAt,
            onChanged: (value) => setState(() => _dueAt = value),
          ),
          ],
        ),
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

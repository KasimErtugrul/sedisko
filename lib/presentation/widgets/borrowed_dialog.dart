import 'package:flutter/material.dart';

import '../../data/models/borrowed_book_model.dart';
import 'reminder_date_row.dart';

/// "Ödünç alınan kitap" girişi diyalogu (1.18.0).
///
/// Kitap adı ve sahip zorunludur; yazarlar virgülle ayrılmış düz metin
/// olarak girilir, kayıtta listeye ayrıştırılır. Keşke 35 (1.26.0):
/// 'sahibine geri ver' hatırlatma günü isteğe bağlı seçilir. [existing]
/// verilirse alanlar kayıttan doldurulur ve başlık "Ödünç düzenle" olur;
/// düzenleme sonucu [BorrowedBookModel] kimliğiyle güncellenir (bkz.
/// `LoanController.updateBorrowed`).
///
/// Dönen değer: onaylanırsa `(başlık, yazarlar, sahip, not, gün)` — yazarlar
/// ve not boşsa boş string gelir, çağıran kırpıp temizler; gün `null`
/// hatırlatmasız kayıt demektir; vazgeçilirse `null`.
Future<
    (
      String title,
      String authors,
      String owner,
      String note,
      DateTime? remindAt,
    )?> showBorrowedDialog(
  BuildContext context, {
  BorrowedBookModel? existing,
}) {
  return showDialog<(String, String, String, String, DateTime?)>(
    context: context,
    builder: (dialogContext) => _BorrowedDialog(existing: existing),
  );
}

class _BorrowedDialog extends StatefulWidget {
  const _BorrowedDialog({this.existing});

  final BorrowedBookModel? existing;

  @override
  State<_BorrowedDialog> createState() => _BorrowedDialogState();
}

class _BorrowedDialogState extends State<_BorrowedDialog> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _authorsCtrl =
      TextEditingController(text: widget.existing?.authorsText ?? '');
  late final TextEditingController _ownerCtrl =
      TextEditingController(text: widget.existing?.owner ?? '');
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.existing?.note ?? '');

  DateTime? _remindAt;

  @override
  void initState() {
    super.initState();
    _remindAt = widget.existing?.remindAt;
  }

  String? _titleError;
  String? _ownerError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorsCtrl.dispose();
    _ownerCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existing != null;

  void _submit() {
    final titleError =
        _titleCtrl.text.trim().isEmpty ? 'Kitap adı boş olamaz' : null;
    final ownerError =
        _ownerCtrl.text.trim().isEmpty ? 'Sahip adı boş olamaz' : null;
    if (titleError != null || ownerError != null) {
      setState(() {
        _titleError = titleError;
        _ownerError = ownerError;
      });
      return;
    }
    Navigator.pop(
      context,
      (
        _titleCtrl.text.trim(),
        _authorsCtrl.text.trim(),
        _ownerCtrl.text.trim(),
        _noteCtrl.text.trim(),
        _remindAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Ödünç düzenle' : 'Ödünç al'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          TextField(
            key: const Key('borrowed-title-field'),
            controller: _titleCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Kitap adı *',
              errorText: _titleError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('borrowed-authors-field'),
            controller: _authorsCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Yazar(lar)',
              helperText: 'Virgülle ayır: Orhan Pamuk, Sabahattin Ali',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('borrowed-owner-field'),
            controller: _ownerCtrl,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_ownerError != null) setState(() => _ownerError = null);
            },
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Kimden (sahip) *',
              errorText: _ownerError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('borrowed-note-field'),
            controller: _noteCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Not (isteğe bağlı)',
            ),
          ),
          const SizedBox(height: 16),
          // Keşke 35 (1.26.0): 'sahibine geri ver' hatırlatması — komşunun
          // kitabı altı ayda bende kalmasın.
          ReminderDateRow(
            label: 'Sahibine geri ver hatırlatması (isteğe bağlı)',
            selected: _remindAt,
            onChanged: (value) => setState(() => _remindAt = value),
          ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _titleCtrl,
          builder: (context, title, _) {
            return ValueListenableBuilder<TextEditingValue>(
              valueListenable: _ownerCtrl,
              builder: (context, owner, _) {
                final enabled =
                    title.text.trim().isNotEmpty && owner.text.trim().isNotEmpty;
                return FilledButton(
                  key: const Key('borrowed-submit-button'),
                  onPressed: enabled ? _submit : null,
                  child: const Text('Kaydet'),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

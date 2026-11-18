import 'package:flutter/material.dart';

/// Yazar adını değiştirme / birleştirme diyaloğu.
///
/// "Kasim" ve "Kasım" gibi yazımlar arama anahtarında aynı gruba katlanır;
/// kitaplıkta tek kart görünür. Bu diyalog kartın arkasındaki yazımları
/// gösterir ve kullanıcının seçtiği isimle TÜM kitaplarda tek yazıma
/// sabitler (bkz. LibraryController.renameAuthor).
///
/// Dönen değer: onaylanırsa yeni ad (kırpılmış), vazgeçilirse `null`.
Future<String?> showAuthorRenameDialog(
  BuildContext context, {
  required String currentName,
  required List<String> spellings,
  required int affectedBooks,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _AuthorRenameDialog(
      currentName: currentName,
      spellings: spellings,
      affectedBooks: affectedBooks,
    ),
  );
}

class _AuthorRenameDialog extends StatefulWidget {
  const _AuthorRenameDialog({
    required this.currentName,
    required this.spellings,
    required this.affectedBooks,
  });

  final String currentName;
  final List<String> spellings;
  final int affectedBooks;

  @override
  State<_AuthorRenameDialog> createState() => _AuthorRenameDialogState();
}

class _AuthorRenameDialogState extends State<_AuthorRenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.currentName);

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String raw) {
    if (raw.trim().isEmpty) return 'Yazar adı boş olamaz';
    return null;
  }

  void _submit() {
    final error = _validate(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variants = widget.spellings
        .where((s) => s != widget.currentName)
        .toList(growable: false);

    return AlertDialog(
      title: const Text('Yazar adını değiştir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: _error,
              helperText: 'Bu yazarın tüm kitaplarında bu isim yazacak',
            ),
          ),
          const SizedBox(height: 12),
          if (variants.isNotEmpty) ...[
            Text(
              'Kitaplıkta bu yazar farklı yazımlarla da geçiyor:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            for (final variant in variants)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '• $variant',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Kaydet deyince bu yazımlar da yukarıdaki isimle birleşir.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            widget.affectedBooks == 0
                ? 'Bu isimde kitap bulunmuyor.'
                : '${widget.affectedBooks} kitabın yazar bilgisi güncellenecek.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

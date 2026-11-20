/// Satın alma listesi kaydı ekleme/düzenleme diyaloğu.
///
/// 1.18.0: Elle ekleme FAB'ı ve kart düzenlemesi bu diyalogu kullanır.
/// ISBN buradan girilmez; Open Library aramasından gelen kayıtlarda
/// ISBN otomatik taşınır. Başarılı kayıtta (başlık, yazarlar, not)
/// üçlüsü döner; 'Vazgeç' ve dışarı dokunuş `null` döner.
library;

import 'package:flutter/material.dart';

import '../../data/models/wishlist_item_model.dart';

Future<(String title, String authors, String note)?> showWishlistItemDialog(
  BuildContext context, {
  WishlistItemModel? existing,
}) {
  final editing = existing != null;
  final titleCtrl = TextEditingController(text: editing ? existing.title : '');
  final authorsCtrl =
      TextEditingController(text: editing ? existing.authors.join(', ') : '');
  final noteCtrl = TextEditingController(text: editing ? (existing.note ?? '') : '');
  final formKey = GlobalKey<FormState>();

  return showDialog<(String, String, String)>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(editing ? 'Düzenle' : 'Elle ekle'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: titleCtrl,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Kitap adı gerekli' : null,
              decoration: const InputDecoration(
                labelText: 'Kitap adı *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: authorsCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Yazar(lar) (virgülle)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.of(dialogContext).pop((
              titleCtrl.text.trim(),
              authorsCtrl.text.trim(),
              noteCtrl.text.trim(),
            ));
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
}

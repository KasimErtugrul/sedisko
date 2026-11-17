import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';
import '../controllers/library_controller.dart';

/// Raf seçim alt sayfası: mevcut raflar + 'Rafsız' + 'Yeni raf...'.
///
/// Dönen değer: raf adı, '' (rafsız) ya da null (iptal).
/// Detay sayfasındaki raf kartı, listede uzun basma ve yazar toplama
/// aksiyonu bu tek seçiciyi paylaşır.
Future<String?> showShelfPickerSheet(
  BuildContext context, {
  String? currentShelf,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ShelfPickerSheet(currentShelf: currentShelf),
  );
}

/// [book] için raf seç ve taşı; başarıda bilgi balonu göster.
/// İptal ya da aynı raf seçiminde hiçbir şey yapmaz.
Future<void> pickShelfAndMove(BuildContext context, BookModel book) async {
  final shelf = await showShelfPickerSheet(context, currentShelf: book.shelf);
  if (shelf == null) return; // İptal
  if (shelf.trim() == book.shelf.trim()) return; // Aynı raf, işlem yok

  final controller = Get.find<LibraryController>();
  final ok = await controller.moveToShelf(book, shelf);
  if (!ok) return; // Hata mesajı LibraryController'da gösterildi.

  final display = shelf.trim().isEmpty ? 'Rafsız' : shelf.trim();
  Get.snackbar(
    'Taşındı',
    '${book.title} → $display rafına taşındı.',
    snackPosition: SnackPosition.BOTTOM,
  );
}

class _ShelfPickerSheet extends StatelessWidget {
  const _ShelfPickerSheet({this.currentShelf});

  final String? currentShelf;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LibraryController>();
    final current = (currentShelf ?? '').trim();

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Kitabı hangi rafa taşımak istersin?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final shelf in controller.shelves)
            ListTile(
              leading: const Icon(Icons.shelves),
              title: Text(shelf),
              trailing: shelf == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, shelf),
            ),
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: const Text('Rafsız'),
            trailing: current.isEmpty ? const Icon(Icons.check) : null,
            onTap: () => Navigator.pop(context, ''),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Yeni raf...'),
            onTap: () async {
              final created = await _promptNewShelf(context);
              if (created != null && context.mounted) {
                Navigator.pop(context, created);
              }
            },
          ),
        ],
      ),
    );
  }

  /// Yeni raf adı ister; boş ad ve mevcut rafla eşleşen ad reddedilir
  /// (aksan/büyük harf farkı da sayılır ki sinsi ikiz raflar oluşmasın).
  Future<String?> _promptNewShelf(BuildContext context) {
    final input = TextEditingController();
    // Hata, StatefulBuilder'ın builder'ının DIŞINDA tutulur; aksi halde
    // her setState rebuild'inde sıfırlanır ve mesaj hiç gösterilmez.
    String? error;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          void submit() {
            final name = input.text.trim();
            if (name.isEmpty) {
              setState(() => error = 'Raf adı gerekli');
              return;
            }
            final controller = Get.find<LibraryController>();
            final key = TextNormalizer.searchKey(name);
            final duplicate = controller.shelves
                .any((s) => TextNormalizer.searchKey(s) == key);
            if (duplicate) {
              setState(() => error = 'Bu raf zaten var');
              return;
            }
            Navigator.pop(dialogContext, name);
          }

          return AlertDialog(
            title: const Text('Yeni raf'),
            content: TextField(
              controller: input,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (error != null) setState(() => error = null);
              },
              decoration: InputDecoration(
                labelText: 'Raf adı',
                hintText: 'örn. Salon - 2. raf',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: submit,
                child: const Text('Oluştur'),
              ),
            ],
          );
        },
      ),
    );
  }
}

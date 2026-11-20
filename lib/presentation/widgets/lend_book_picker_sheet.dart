import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/book_model.dart';
import '../controllers/library_controller.dart';
import '../controllers/loan_controller.dart';
import 'lend_dialog.dart';

/// Keşke 38 (1.20.0): "Ödünç verilenler" sayfasının sağ alt düğmesi.
/// Eski davranış boş sayfanın "kitap detayına dön" demesiydi; iki kardeş
/// sayfa farklı davranıyordu ("Ödünç aldıklarım" sayfasında FAB vardı).
///
/// Akış: sürüyor ödünçü OLMAYAN kitaplar listelenir → kitap seçilir →
/// kişi/not diyaloğu ([showLendDialog]) açılır → kayıt yazılır. Kitap
/// detayındaki "Ödünç ver" aksiyonuyla aynı denetleyici yolunu kullanır;
/// iş kuralları (aktif ödünçte tekrar verme, depo hatası bildirimi)
/// LoanController'dadır.
Future<void> showLendBookPickerSheet(BuildContext context) async {
  final library = Get.find<LibraryController>();
  final loanController = Get.find<LoanController>();
  final lendable = [
    for (final book in library.books)
      if (loanController.activeLoanFor(book.id) == null) book,
  ];

  if (lendable.isEmpty) {
    Get.snackbar(
      'Ödünç verilecek kitap yok',
      'Kitaplıkta kitap yok ya da hepsi sürüyor bir ödünçte.',
      snackPosition: SnackPosition.BOTTOM,
    );
    return;
  }

  final picked = await showModalBottomSheet<BookModel>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        itemCount: lendable.length + 1,
        itemBuilder: (sheetItemContext, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Kimi ödünç vereceksin? Önce kitabı seç.',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            );
          }
          final book = lendable[index - 1];
          return ListTile(
            key: ValueKey('lend-pick-${book.id}'),
            leading: const Icon(Icons.book_outlined),
            title: Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: book.authors.isEmpty
                ? null
                : Text(
                    book.authorsText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            onTap: () => Navigator.pop(sheetContext, book),
          );
        },
      ),
    ),
  );
  if (picked == null || !context.mounted) return;

  final result = await showLendDialog(context);
  if (result == null) return;
  final person = result.$1;
  final ok =
      await loanController.lendBook(picked, person, note: result.$2);
  if (ok) {
    Get.snackbar(
      'Ödünç kaydedildi',
      '"${picked.title}" $person kişisine verildi.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

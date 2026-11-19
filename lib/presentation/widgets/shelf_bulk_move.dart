import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';
import '../../domain/services/book_thickness.dart';
import '../controllers/library_controller.dart';
import '../controllers/shelf_organize_controller.dart';
import '../utils/app_navigation.dart';
import 'shelf_picker_sheet.dart';

/// Bir raftaki TÜM kitapları başka bir rafa toplu taşıma (1.16.0, kullanıcı
/// isteği: "a rafındaki tüm kitapları b rafına aktarabiliyormuyum").
///
/// Akış: raf seçici açılır (hedef 'Rafsız' ya da 'Yeni raf...' da olabilir)
/// → tanımlı hedef rafta yer yoksa kullanıcıya taşma hesabıyla sorulur
/// (tek kitap taşımadaki "Yine de taşı" kuralıyla aynı çizgi) → kitaplar
/// tek tek taşınır ([LibraryController.moveManyToShelf]; okuma durumu,
/// sayfa ve günlük dokunulmaz) → kaynak raf tamamen boşaldıysa sayfadan
/// Raflar sekmesine dönülür.
///
/// Kapasite hesabı 1.15.0'daki kalınlık modeline uyar: kalınlık hesabı
/// açıksa her kitabın kapladığı yer sayfa sayısından (yarım birim) toplanır,
/// kapalıysa kitap sayısıdır.
Future<void> moveWholeShelf(BuildContext context, String sourceShelf) async {
  final library = Get.find<LibraryController>();
  final targets =
      library.books.where((b) => b.shelf.trim() == sourceShelf.trim()).toList();
  if (targets.isEmpty) {
    Get.snackbar(
      'Taşınacak kitap yok',
      '"$sourceShelf" rafında kitap bulunmuyor.',
      snackPosition: SnackPosition.BOTTOM,
    );
    return;
  }

  final shelf = await showShelfPickerSheet(context, currentShelf: sourceShelf);
  if (shelf == null) return; // İptal
  if (TextNormalizer.searchKey(shelf.trim()) ==
      TextNormalizer.searchKey(sourceShelf.trim())) {
    return; // Aynı raf seçildi; işlem yok
  }

  final confirmed = await _confirmCapacity(shelf, targets);
  if (!confirmed) return;

  final moved = await library.moveManyToShelf(targets, shelf);
  if (moved == 0) return; // Hata mesajı LibraryController'da gösterildi.

  // Kaynak raf tamamen boşaldıysa raf sayfası artık anlamsız: Raflar
  // sekmesine dön. Kısmi taşınmada kalan kitaplar görünür kalsın.
  final remaining =
      library.books.where((b) => b.shelf.trim() == sourceShelf.trim()).length;
  if (remaining == 0) AppNav.pop();

  final display = shelf.trim().isEmpty ? 'Rafsız' : shelf.trim();
  final suffix = moved < targets.length
      ? ' (${targets.length - moved} kitap taşınmadı)'
      : '';
  Get.snackbar(
    'Taşındı',
    '$moved kitap "$display" rafına toplandı$suffix.',
    snackPosition: SnackPosition.BOTTOM,
  );
}

/// Hedef rafta yer yoksa kullanıcıya taşma hesabıyla sorulur; yer varsa
/// (ya da raf tanımsızsa) onay gerekmez — raf seçici zaten bilinçli adım.
Future<bool> _confirmCapacity(
  String targetShelf,
  List<BookModel> targets,
) async {
  if (!Get.isRegistered<ShelfOrganizeController>()) return true;
  final organize = Get.find<ShelfOrganizeController>();
  final definition = organize.shelfByName(targetShelf);
  if (definition == null) return true; // Tanımsız raf / Rafsız: denetim yok

  final thickness = organize.thicknessAware.value;
  final incoming = targets.fold<int>(
    0,
    (sum, book) =>
        sum +
        BookThickness.costHalfUnits(
          book.pageCount,
          thicknessAware: thickness,
        ),
  );
  final capacity = thickness ? definition.capacity * 2 : definition.capacity;
  final used = thickness
      ? organize.shelfHalfUnits(targetShelf)
      : organize.shelfCount(targetShelf);
  final remaining = capacity - used;
  if (incoming <= remaining) return true; // Sığıyor

  final name = definition.name;
  final String detail;
  if (thickness) {
    detail = remaining > 0
        ? '"$name" rafında ${BookThickness.formatHalf(remaining)} birim yer '
            'var. Taşınacak kitaplar ${BookThickness.formatHalf(incoming)} '
            'birim yer kaplıyor — ${BookThickness.formatHalf(incoming - remaining)} '
            'birim taşar.'
        : '"$name" rafı dolu '
            '(${organize.shelfOccupancyText(targetShelf, definition.capacity)}).';
  } else {
    detail = remaining > 0
        ? '"$name" rafında $remaining kitaplık yer var. '
            '${targets.length} kitap taşınacak — '
            '${targets.length - remaining} kitap taşar.'
        : '"$name" rafı dolu ($used/${definition.capacity}).';
  }

  final result = await Get.dialog<bool>(
    AlertDialog(
      title: const Text('Hedef raf taşacak'),
      content: Text('$detail Yine de taşısın mı?'),
      actions: [
        TextButton(
          key: const ValueKey('bulk-move-cancel'),
          onPressed: () => Get.back(result: false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('bulk-move-confirm'),
          onPressed: () => Get.back(result: true),
          child: const Text('Yine de taşı'),
        ),
      ],
    ),
  );
  return result ?? false;
}

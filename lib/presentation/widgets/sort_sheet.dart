import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/services/book_sort.dart';
import '../controllers/library_controller.dart';

/// Kitap sıralama alt sayfası.
///
/// Üstte yön seçimi, altta sıralama alanları listesi. Yön etiketleri
/// alana göre konuşur (keşke 17, 1.25.0): yazı alanlarında "A'dan Z'ye /
/// Z'den A'ya", sayı ve tarihte "Azdan çoğa / Çoktan aza" — "Artan
/// nedir, azalan nedir?" sorusu artık sorulmaz. Alan seçilince sayfa
/// kapanır ve liste hemen güncellenir; yön değişimi sayfada kalır ki
/// kullanıcı artırdıktan sonra alanı aynı sayfadan seçebilsin. Eksik
/// bilgi (bilinmeyen sayfa sayısı, tarihsiz kitap, rafsız kitap) her
/// iki yönde de listenin sonuna gider; kuralın açıklaması
/// BookSorter'dadır.
Future<void> showBookSortSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _BookSortSheet(),
  );
}

class _BookSortSheet extends StatelessWidget {
  const _BookSortSheet();

  static const _icons = <BookSortField, IconData>{
    BookSortField.title: Icons.sort_by_alpha,
    BookSortField.author: Icons.person_outline,
    BookSortField.publisher: Icons.business,
    BookSortField.shelf: Icons.shelves,
    BookSortField.pageCount: Icons.menu_book_outlined,
    BookSortField.currentPage: Icons.bookmark_outline,
    BookSortField.startedAt: Icons.play_circle_outline,
    BookSortField.finishedAt: Icons.check_circle_outline,
    BookSortField.publishDate: Icons.event,
  };

  static const _alphabeticalFields = <BookSortField>{
    BookSortField.title,
    BookSortField.author,
    BookSortField.publisher,
    BookSortField.shelf,
  };

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LibraryController>();

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Kitapları sırala',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Obx(() {
              // Keşke 17 (1.25.0): "'Artan / Azalan' yerine 'A'dan Z'ye /
              // Z'den A'ya' yazsaydı düşünmezdim." Etiketler seçili alana
              // göre kurulur; yazı alanında harf dili, sayı ve tarihte
              // miktar dili konuşur.
              final alphabetical = _alphabeticalFields
                  .contains(controller.sortField.value);
              return SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: Text(alphabetical ? "A'dan Z'ye" : 'Azdan çoğa'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: Text(alphabetical ? "Z'den A'ya" : 'Çoktan aza'),
                  ),
                ],
                selected: {controller.sortAscending.value},
                onSelectionChanged: (selection) =>
                    controller.sortAscending.value = selection.first,
              );
            }),
          ),
          for (final field in BookSortField.values)
            Obx(() {
              final selected = controller.sortField.value == field;
              return ListTile(
                key: ValueKey('sort-option-${field.name}'),
                leading: Icon(
                  _icons[field],
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(field.label),
                trailing:
                    selected ? const Icon(Icons.check) : null,
                onTap: () {
                  controller.setSort(
                    field,
                    ascending: controller.sortAscending.value,
                  );
                  Navigator.pop(context);
                },
              );
            }),
        ],
      ),
    );
  }
}

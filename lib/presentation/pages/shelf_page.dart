import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/library_controller.dart';
import '../routes/app_routes.dart';
import '../widgets/book_tile.dart';
import '../widgets/status_filter_row.dart';

/// Bir rafın kitaplarını gösteren sayfa.
///
/// [shelf] null → tüm kitaplar; 'Rafsız' → rafsız kitaplar; aksi halde raf adı.
/// Durum filtresi çipleriyle 200+ kitaplı raflarda daraltma yapılabilir.
class ShelfPage extends GetView<LibraryController> {
  const ShelfPage({super.key, this.shelf});

  final String? shelf;

  String get _title => shelf == null ? 'Tüm kitaplar' : shelf!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = controller.filteredBooks(shelf: shelf);
        return Column(
          children: [
            const StatusFilterRow(),
            Expanded(
              child: items.isEmpty
                  ? _EmptyShelfMessage(shelfEmpty: _shelfGenuinelyEmpty)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final book = items[index];
                        return BookTile(
                          key: ValueKey(book.id),
                          book: book,
                          onTap: () =>
                              Get.toNamed(Routes.detail, arguments: book.id),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  /// Raf gerçekten boş mu, yoksa durum/arama filtresi mi boşalttı?
  ///
  /// [shelf] null iken sayfa yalnız kitaplık doluyken açılabildiği için
  /// "boş raf" kabul edilmez; filtre mesajı gösterilir.
  bool get _shelfGenuinelyEmpty {
    if (shelf == null) return false;
    return controller.books.every((b) {
      final s = b.shelf.trim();
      return shelf == 'Rafsız' ? s.isNotEmpty : s != shelf;
    });
  }
}

class _EmptyShelfMessage extends StatelessWidget {
  const _EmptyShelfMessage({required this.shelfEmpty});

  final bool shelfEmpty;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              shelfEmpty ? Icons.shelves : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              shelfEmpty ? 'Bu rafta kitap yok.' : 'Filtrelere uyan kitap yok.',
              textAlign: TextAlign.center,
            ),
            if (!shelfEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Durum filtresini "Hepsi"ye alıp tekrar dene.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

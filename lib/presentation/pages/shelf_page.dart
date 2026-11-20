import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/text_normalizer.dart';
import '../controllers/library_controller.dart';
import '../routes/app_routes.dart';
import '../utils/app_navigation.dart';
import '../widgets/author_rename_dialog.dart';
import '../widgets/book_tile.dart';
import '../widgets/responsive/responsive_center.dart';
import '../widgets/shelf_bulk_move.dart';
import '../widgets/shelf_picker_sheet.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/status_filter_row.dart';

/// Bir rafın (ya da yazar filtresinin) kitaplarını gösteren sayfa.
///
/// [shelf] null → tüm kitaplar; 'Rafsız' → rafsız kitaplar; aksi halde raf adı.
/// [authorKey] verilirse yalnız o yazarın kitapları listelenir; detay
/// sayfasındaki yazar adına dokununca bu görünüm açılır.
///
/// Genel filtreleme: eylem satırındaki "Süz" düğmesi yazar seçimi açar;
/// yazar filtresi aktifken "Rafa topla" aksiyonu aynı yazarın kitaplarını
/// tek rafta birleştirir. Durum filtresi çipleri her iki görünümde de çalışır.
///
/// **1.20.0 (keşke 16):** sırala/süz/taşı işlemleri yazısız ikonlardan
/// yazılı düğmelere taşındı — kullanıcı "hangisi ne yapıyor belli değil"
/// notu almıştı. Anahtarlar ve tooltip'ler ("shelf-bulk-move", "Sırala",
/// Icons.filter_list) eski ikon düğmelerinden aynen taşındı.
class ShelfPage extends StatefulWidget {
  const ShelfPage({super.key, this.shelf, this.authorKey});

  final String? shelf;
  final String? authorKey;

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  // initState'te yakalanır; dispose'ta controller artık kayıtlı olmasa
  // bile (test teardown sırası) filtre temizlenebilsin.
  late final LibraryController _controller = Get.find<LibraryController>();

  @override
  void initState() {
    super.initState();
    _controller.authorFilter.value = widget.authorKey;
  }

  @override
  void dispose() {
    // Yazar filtresi yalnız bu sayfa bağlamında anlamlı; çıkarken sıfırla
    // ki ana sayfa aramaları etkilenmesin.
    _controller.authorFilter.value = null;
    super.dispose();
  }

  String get _title {
    final authorKey = _controller.authorFilter.value;
    if (authorKey != null) {
      return _controller.authorDisplayName(authorKey) ?? 'Yazar filtresi';
    }
    return widget.shelf == null ? 'Tüm kitaplar' : widget.shelf!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Obx(() => Text(_title))),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = _controller.filteredBooks(shelf: widget.shelf);
        return Column(
          children: [
            _actionRow(context),
            const StatusFilterRow(),
            _authorBanner(),
            Expanded(
              child: items.isEmpty
                  ? _EmptyListMessage(shelfEmpty: _shelfGenuinelyEmpty)
                  : // Geniş ekranda satırlar iki uca dağılmasın: tavan genişlik.
                  ResponsiveCenter(
                      maxWidth: 720,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final book = items[index];
                          return BookTile(
                            key: ValueKey(book.id),
                            book: book,
                            onTap: () =>
                                Get.toNamed(Routes.detail, arguments: book.id),
                            onLongPress: () => pickShelfAndMove(context, book),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }

  /// Keşke 16 (1.20.0): yazılı eylem satırı. Sırala ve süz her görünümde;
  /// "Rafı taşı" yalnız somut rafta (tüm kitaplığı tek rafa toplamak kaza
  /// riski taşır — 1.16.0 kararı); "Rafa topla" ve "Adı değiştir" yalnız
  /// yazar filtresi aktifken.
  Widget _actionRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Obx(() {
        final authorActive = _controller.authorFilter.value != null;
        return Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            Obx(() {
              final customSort = _controller.hasCustomSort;
              return _action(
                context,
                tooltip: 'Sırala',
                label: 'Sırala',
                highlighted: customSort,
                icon: Badge(
                  isLabelVisible: customSort,
                  child: const Icon(Icons.sort),
                ),
                onPressed: () => showBookSortSheet(context),
              );
            }),
            // Kullanıcı isteği (1.16.0): "a rafındaki tüm kitapları b
            // rafına aktarabiliyormuyum" — somut raf sayfalarında tüm
            // kitapları toplu taşıma.
            if (widget.shelf != null)
              _action(
                context,
                tooltip: 'Bu raftaki tüm kitapları başka rafa taşı',
                label: 'Rafı taşı',
                buttonKey: const ValueKey('shelf-bulk-move'),
                icon: const Icon(Icons.drive_file_move_outline),
                onPressed: () => moveWholeShelf(context, widget.shelf!),
              ),
            _action(
              context,
              tooltip: 'Filtrele',
              label: 'Süz',
              highlighted: authorActive,
              icon: Badge(
                isLabelVisible: authorActive,
                child: const Icon(Icons.filter_list),
              ),
              onPressed: () => _showAuthorFilterSheet(context),
            ),
            // Yazar filtresi aktifken: aynı yazarın kitaplarını tek raf
            // toplama (klasör ikonu, "tüm rafı taşı"dan ayrışsın).
            if (authorActive)
              _action(
                context,
                tooltip: 'Bu yazarın kitaplarını bir rafa topla',
                label: 'Rafa topla',
                icon: const Icon(Icons.folder_special_outlined),
                onPressed: () => _collectAuthorToShelf(context),
              ),
            // Yazar filtresi aktifken: yazar adını değiştir (yazım birleştirme).
            if (authorActive)
              _action(
                context,
                tooltip: 'Yazarı yeniden adlandır',
                label: 'Adı değiştir',
                icon: const Icon(Icons.drive_file_rename_outline),
                onPressed: () => _renameAuthor(context),
              ),
          ],
        );
      }),
    );
  }

  /// Yazılı eylem düğmesi: Tooltip sarmalı — arayüzde yazı, ekran
  /// okuyucuda ve testlerde tooltip mesajı aynı kalır.
  Widget _action(
    BuildContext context, {
    required String tooltip,
    required String label,
    required Widget icon,
    required VoidCallback onPressed,
    Key? buttonKey,
    bool highlighted = false,
  }) {
    final color =
        highlighted ? Theme.of(context).colorScheme.primary : null;
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          style: color == null
              ? null
              : TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Yazar filtresi aktifken listenin üstündeki bilgilendirme çipi.
  Widget _authorBanner() {
    return Obx(() {
      final authorKey = _controller.authorFilter.value;
      if (authorKey == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: const Icon(Icons.person_outline, size: 18),
            label: Text(
              _controller.authorDisplayName(authorKey) ?? 'Yazar',
            ),
            onDeleted: () => _controller.authorFilter.value = null,
            deleteButtonTooltipMessage: 'Yazar filtresini temizle',
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    });
  }

  /// Yazar seçim sayfası: kitaplıktaki tüm yazarlar + 'Tümü'.
  void _showAuthorFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Obx(() {
            final selected = _controller.authorFilter.value;
            final authors = _controller.authors;
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Hangi yazarın kitapları görünsün?',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                if (authors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Kitaplıkta yazar bilgisi yok.'),
                  ),
                ListTile(
                  leading: const Icon(Icons.clear_all),
                  title: const Text('Tümü (filtre yok)'),
                  trailing: selected == null ? const Icon(Icons.check) : null,
                  onTap: () {
                    _controller.authorFilter.value = null;
                    Navigator.pop(sheetContext);
                  },
                ),
                for (final author in authors)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(author),
                    trailing: selected == TextNormalizer.searchKey(author)
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () {
                      _controller.authorFilter.value =
                          TextNormalizer.searchKey(author);
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            );
          }),
        );
      },
    );
  }

  /// Yazar adını değiştirir: "Kasim" yazan kitapların hepsi "Kasım" olur.
  /// Diyalog kitaplıktaki tüm yazımları gösterir; onaydan sonra filtre yeni
  /// adın anahtarına taşınır (ad değişirse liste boş kalmasın).
  Future<void> _renameAuthor(BuildContext context) async {
    final authorKey = _controller.authorFilter.value;
    if (authorKey == null) return;
    final displayName = _controller.authorDisplayName(authorKey);
    if (displayName == null) return;

    final newName = await showAuthorRenameDialog(
      context,
      currentName: displayName,
      spellings: _controller.authorSpellings(authorKey),
      affectedBooks: _controller.authorBookCount(authorKey),
    );
    if (newName == null || newName == displayName) return;

    final changed = await _controller.renameAuthor(authorKey, newName);
    if (changed == 0) return;

    // Yeni adın arama anahtarı eski adınkiyle aynı olmayabilir (örn.
    // 'Kasim' → 'M. Kasım'); filtre güncel gruba taşınır.
    _controller.authorFilter.value = TextNormalizer.searchKey(newName);

    Get.snackbar(
      'Yazar güncellendi',
      '$changed kitap "$newName" olarak yazıldı.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Aktif yazar filtresindeki kitapları seçilen rafa toplar.
  Future<void> _collectAuthorToShelf(BuildContext context) async {
    final targets = _controller.filteredBooks(shelf: widget.shelf);
    if (targets.isEmpty) return;

    final shelf = await showShelfPickerSheet(context);
    if (shelf == null) return; // İptal

    final total = targets.length;
    final moved = await _controller.moveManyToShelf(targets, shelf);
    if (moved == 0) return;

    // Kitaplar başka bir rafa toplandıysa bu raf sayfası boşalır; kullanıcıyı
    // güncel raf kartlarına geri al. AppNav.pop kullanılır: GetX 4.x'te
    // Get.back(), açık bir snackbar gördüğünde pop'u yapmadan döner (örn.
    // kısmi taşıma hatası bildirimi); bu yüzden çıkış önce yapılır ve
    // snackbar en son gösterilmeli.
    if (widget.shelf != null && shelf.trim() != widget.shelf) {
      AppNav.pop();
    }

    final display = shelf.trim().isEmpty ? 'Rafsız' : shelf.trim();
    final suffix = moved < total ? ' (${total - moved} kitap taşınmadı)' : '';
    Get.snackbar(
      'Taşındı',
      '$moved kitap "$display" rafına toplandı$suffix.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Raf gerçekten boş mu, yoksa durum/arama/yazar filtresi mi boşalttı?
  ///
  /// [shelf] null iken sayfa yalnız kitaplık doluyken açılabildiği için
  /// "boş raf" kabul edilmez; filtre mesajı gösterilir.
  bool get _shelfGenuinelyEmpty {
    if (widget.shelf == null) return false;
    return _controller.books.every((b) {
      final s = b.shelf.trim();
      return widget.shelf == 'Rafsız' ? s.isNotEmpty : s != widget.shelf;
    });
  }
}

class _EmptyListMessage extends StatelessWidget {
  const _EmptyListMessage({required this.shelfEmpty});

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
                'Durum/yazar filtrelerini "Hepsi"ye alıp tekrar dene.',
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

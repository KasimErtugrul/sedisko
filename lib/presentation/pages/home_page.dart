import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/services/home_feed.dart';
import '../controllers/library_controller.dart';
import '../controllers/settings_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../utils/app_navigation.dart';
import '../widgets/book_tile.dart';
import '../widgets/home/author_strip.dart';
import '../widgets/home/book_strip.dart';
import '../widgets/home/home_empty_state.dart';
import '../widgets/home/home_section_header.dart';
import '../widgets/home/home_summary_row.dart';
import '../widgets/home/shelf_summary_grid.dart';
import '../widgets/shelf_picker_sheet.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/status_filter_row.dart';

/// Ana sayfa sekmesi: kitap odaklı, zenginleştirilmiş özet akışı.
///
/// Bu dosya yalnız kompozisyondan sorumludur (tanrı dosyası değil):
/// görsel parçalar `widgets/home/` altında küçük dosyalara bölünmüştür,
/// bölüm verileri [HomeFeed] saf servisinden gelir.
///
/// Arama boşken akış sırası:
/// 1. Özet satırı (toplam / okunuyor / bitti / favori)
/// 2. "Devam eden kitaplar" — yatay şerit
/// 3. "Favoriler" — daima görünür; boşken yönlendirme ipucu kartı
/// 4. "Bitirme hedefleri" — geri sayımlı yatay şerit
/// 5. "Son eklenenler" — eklenme tarihi azalan yatay şerit
/// 6. "En çok sayfalı kitaplar" — yatay şerit
/// 7. "En çok kitaba sahip yazarlar" — yatay yazar kartları; "Tümü"
///    Yazarlar sekmesine geçirir
/// 8. "Rafların" — iki kolonlu raf grid'i (gridview); "Tümü" Raflar
///    sekmesine geçirir
/// 9. "Bu ay bitirdiklerin" — bu ay bitirilenler şeridi
/// 10. "Not aldıkların" — notlu kitaplar şeridi
///
/// "Tüm kitaplar" listesi ana sayfada yoktur: tam kitaplık Raflar
/// sekmesindeki "Tüm kitaplar" kartından açılır.
///
/// Tüm akış `ListView.builder` ile tek sanallaştırılmış listede kurulur;
/// 200+ kitapta yalnız görünür öğeler inşa edilir.
class HomePage extends GetView<LibraryController> {
  const HomePage({super.key, this.onOpenShelves, this.onOpenAuthors});

  /// "Rafların" bölümündeki "Tümü": kabukta Raflar sekmesine geçer.
  /// Kabuk dışında (bazı testler) null verilir; aksiyon gizlenir.
  final VoidCallback? onOpenShelves;

  /// "En çok kitaba sahip yazarlar" bölümündeki "Tümü": Yazarlar sekmesi.
  final VoidCallback? onOpenAuthors;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitaplığım'),
        actions: [
          // Arama sonuçlarını (ve raf sayfalarını) sıralar.
          Obx(
            () => IconButton(
              tooltip: 'Sırala',
              icon: Badge(
                isLabelVisible: controller.hasCustomSort,
                child: const Icon(Icons.sort),
              ),
              onPressed: () => showBookSortSheet(context),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: _buildSearchField(),
              ),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (controller.books.isEmpty) {
                    return const HomeEmptyState(hasBooks: false);
                  }
                  final searching = controller.query.value.trim().isNotEmpty;
                  return searching ? _searchResults() : _homeFeed();
                }),
              ),
            ],
          ),
          Obx(
            () => controller.isLookingUp.value
                ? Container(
                    color: Colors.black38,
                    alignment: Alignment.center,
                    child: const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text("Open Library'de aranıyor..."),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Kitap ekle'),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: controller.searchCtrl,
      onChanged: (v) => controller.query.value = v,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Kitap, yazar, raf veya ISBN ara',
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Obx(
          () => controller.query.value.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Aramayı temizle',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.searchCtrl.clear();
                    controller.query.value = '';
                  },
                ),
        ),
      ),
    );
  }

  /// Arama yazılırken durum filtresi + sonuç listesi gösterilir.
  Widget _searchResults() {
    final items = controller.filteredBooks();
    return Column(
      children: [
        const StatusFilterRow(),
        Expanded(
          child: items.isEmpty
              ? const HomeEmptyState(hasBooks: true)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final book = items[index];
                    return BookTile(
                      key: ValueKey('search-${book.id}'),
                      book: book,
                      onTap: () =>
                          Get.toNamed(Routes.detail, arguments: book.id),
                      // Uzun bas: kitabı başka rafa taşı.
                      onLongPress: () => pickShelfAndMove(context, book),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Ana akış: özet + bölüm şeritleri, tek sanallaştırılmış liste.
  ///
  /// "Favoriler" bölümü kitaplıkta favori olmasa bile görünür; boşken
  /// kullanıcıya favorileştirmeyi öğreten ipucu kartı gösterilir.
  /// Diğer bölümler yalnız doluysa listeye girer, yer tutmaz.
  Widget _homeFeed() {
    final books = controller.books;
    final topAuthors = HomeFeed.topAuthors(books);
    final finishedThisMonth = HomeFeed.finishedThisMonth(books, DateTime.now());

    final sections = <_FeedSection>[
      if (controller.readingBooks.isNotEmpty)
        _FeedSection(
          'Devam eden kitaplar',
          BookStrip(books: controller.readingBooks),
        ),
      _FeedSection(
        'Favoriler',
        BookStrip(books: controller.favoriteBooks),
        isEmpty: controller.favoriteBooks.isEmpty,
        emptyMessage: 'Henüz favori kitabın yok.\n'
            'Kitap detayındaki kalp ikonuyla favorilerine ekleyebilirsin.',
      ),
      if (controller.goalBooks.isNotEmpty)
        _FeedSection(
          'Bitirme hedefleri',
          BookStrip(books: controller.goalBooks, emphasizeGoal: true),
        ),
      _FeedSection(
        'Son eklenenler',
        BookStrip(books: HomeFeed.recentlyAdded(books)),
      ),
      if (controller.longestBooks.isNotEmpty)
        _FeedSection(
          'En çok sayfalı kitaplar',
          BookStrip(books: controller.longestBooks),
        ),
      if (topAuthors.isNotEmpty)
        _FeedSection(
          'En çok kitaba sahip yazarlar',
          AuthorStrip(authors: topAuthors),
          onSeeAll: onOpenAuthors,
          actionKey: const ValueKey('see-all-authors'),
        ),
      _FeedSection(
        'Rafların',
        ShelfSummaryGrid(shelves: _shelfSummaries(), onOpen: _openShelf),
        onSeeAll: onOpenShelves,
        actionKey: const ValueKey('see-all-shelves'),
      ),
      if (finishedThisMonth.isNotEmpty)
        _FeedSection(
          'Bu ay bitirdiklerin',
          BookStrip(books: finishedThisMonth),
        ),
      if (controller.notedBooks.isNotEmpty)
        _FeedSection(
          'Not aldıkların',
          BookStrip(books: controller.notedBooks),
        ),
    ];

    final itemCount = 1 + sections.length * 2; // özet + her bölüm (başlık+şerit)

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) return const HomeSummaryRow();
        var cursor = 1;
        for (final section in sections) {
          if (index == cursor) return _sectionHeader(section);
          if (index == cursor + 1) {
            if (section.isEmpty && section.emptyMessage != null) {
              return HomeSectionEmptyHint(message: section.emptyMessage!);
            }
            return section.body;
          }
          cursor += 2;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _sectionHeader(_FeedSection section) {
    return HomeSectionHeader(
      section.title,
      actionLabel: section.onSeeAll == null ? null : 'Tümü',
      onAction: section.onSeeAll,
      actionKey: section.actionKey,
    );
  }

  List<ShelfSummary> _shelfSummaries() {
    final controller = this.controller;
    return controller.shelfKeys
        .map(
          (key) => ShelfSummary(
            key: key,
            total: controller.shelfCount(key),
            reading: controller.shelfReadingCount(key),
            finished: controller.shelfFinishedCount(key),
          ),
        )
        .toList();
  }

  void _openShelf(String key) =>
      Get.toNamed(Routes.shelf, arguments: ShelfArgs(shelf: key));

  void _showAddSheet(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Platform desteği ve kullanıcı tercihi birlikte ele alınır.
            if (SettingsController.scanActionsVisible)
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Barkod tara'),
                subtitle:
                    const Text('ISBN ile Open Library\'den bilgileri getir'),
                onTap: () {
                  // AppNav.pop: navigator doğrudan pop'lanır; GetX 4.x'te
                  // Get.back() snackbar açıkken pop yapmadan döner ve sheet
                  // açık kalıp üstüne form biner (bkz. AppNav belgesi).
                  AppNav.pop();
                  controller.addByScan();
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Manuel ekle'),
              subtitle: const Text('Bilgileri kendin gir'),
              onTap: () {
                AppNav.pop();
                Get.toNamed(Routes.form, arguments: const BookFormArgs());
              },
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}

/// Ana akışta gösterilecek bölümün tarifidir; görsel parçalar
/// `widgets/home/` altındaki küçük dosyalarda yaşar.
class _FeedSection {
  const _FeedSection(
    this.title,
    this.body, {
    this.isEmpty = false,
    this.emptyMessage,
    this.onSeeAll,
    this.actionKey,
  });

  final String title;
  final Widget body;

  /// Bölüm boşsa ve [emptyMessage] verilmişse şerit yerine ipucu kartı
  /// gösterilir (yalnız Favoriler bu yolu kullanır).
  final bool isEmpty;
  final String? emptyMessage;

  /// Başlığın sağındaki "Tümü" aksiyonu (null ise aksiyon gizlenir).
  final VoidCallback? onSeeAll;
  final Key? actionKey;
}

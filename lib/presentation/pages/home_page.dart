import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/book_model.dart';
import '../controllers/library_controller.dart';
import '../controllers/settings_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../widgets/book_tile.dart';
import '../widgets/cover_image.dart';
import '../widgets/shelf_picker_sheet.dart';
import '../widgets/sort_sheet.dart';
import '../widgets/status_filter_row.dart';

/// Ana sayfa sekmesi: kitap odaklı özet akışı.
///
/// - Arama boşken: özet satırı (toplam / okunuyor / bitti), "Devam eden
///   kitaplar", "Favoriler" ve "Not aldıkların" yatay kapak şeritleri,
///   ardından tüm kitaplık listesi.
/// - Arama yazılırken: durum filtresi çipleri + eşleşen kitap listesi.
///
/// Tüm liste `ListView.builder` ile tek sanallaştırılmış listede kurulur;
/// 200+ kitapta yalnız görünür öğeler inşa edilir.
class HomePage extends GetView<LibraryController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitaplığım'),
        actions: [
          // Tüm kitaplar bölümünü ve arama sonuçlarını sıralar.
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
                    return const _EmptyState(hasBooks: false);
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
              ? const _EmptyState(hasBooks: true)
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

  /// Ana akış: özet + bölümler + tüm kitaplar, tek sanallaştırılmış liste.
  /// "Tüm kitaplar" bölümü aktif sıralamayı izler ([sortedAll]); bölüm
  /// şeritleri (devam eden / favoriler / notlar) sabit küratörlük sırasıyla
  /// kalır.
  Widget _homeFeed() {
    final reading = controller.readingBooks;
    final favorites = controller.favoriteBooks;
    final noted = controller.notedBooks;
    final all = controller.sortedAll;

    // Bölüm şeritleri yalnız doluysa listeye girer; boş bölümler yer tutmaz.
    final sections = <_Section>[
      if (reading.isNotEmpty) _Section('Devam eden kitaplar', reading),
      if (favorites.isNotEmpty) _Section('Favoriler', favorites),
      if (noted.isNotEmpty) _Section('Not aldıkların', noted),
    ];

    final itemCount =
        1 + sections.length * 2 + 1 + all.length; // özet + (başlık+şerit) + tümü başlığı + kitaplar

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) return _SummaryRow(all: all);
        var cursor = 1;
        for (final section in sections) {
          if (index == cursor) return _SectionHeader(section.title);
          if (index == cursor + 1) {
            return _BookStrip(books: section.books);
          }
          cursor += 2;
        }
        if (index == cursor) {
          return _SectionHeader('Tüm kitaplar', subtitle: '${all.length}');
        }
        final book = all[index - cursor - 1];
        return BookTile(
          key: ValueKey('home-${book.id}'),
          book: book,
          onTap: () => Get.toNamed(Routes.detail, arguments: book.id),
          // Uzun bas: kitabı başka rafa taşı.
          onLongPress: () => pickShelfAndMove(context, book),
        );
      },
    );
  }

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
                  Get.back();
                  controller.addByScan();
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Manuel ekle'),
              subtitle: const Text('Bilgileri kendin gir'),
              onTap: () {
                Get.back();
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

/// Ana akışta yatay şerit olarak gösterilecek bölüm.
class _Section {
  const _Section(this.title, this.books);

  final String title;
  final List<BookModel> books;
}

/// Özet satırı: toplam / okunuyor / bitti sayıları.
class _SummaryRow extends GetView<LibraryController> {
  const _SummaryRow({required this.all});

  final List<BookModel> all;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget stat(String value, String label, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(31),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          stat('${all.length}', 'Toplam', scheme.primary),
          const SizedBox(width: 8),
          stat('${controller.readingCount}', 'Okunuyor', Colors.orange),
          const SizedBox(width: 8),
          stat('${controller.finishedCount}', 'Bitti', Colors.green),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 6),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

/// Yatay kapak şeridi; kitaba dokununca detay sayfası açılır.
class _BookStrip extends StatelessWidget {
  const _BookStrip({required this.books});

  final List<BookModel> books;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final book = books[index];
          return _BookCoverCard(
            key: ValueKey('strip-${book.id}'),
            book: book,
            onTap: () => Get.toNamed(Routes.detail, arguments: book.id),
          );
        },
      ),
    );
  }
}

class _BookCoverCard extends StatelessWidget {
  const _BookCoverCard({
    super.key,
    required this.book,
    required this.onTap,
  });

  final BookModel book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 96,
                    height: 140,
                    child: CoverImage(
                      url: book.coverUrl,
                      path: book.coverPath,
                      width: 96,
                      height: 140,
                    ),
                  ),
                ),
                if (book.isFavorite)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: _FavoriteBadge(),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kapak köşesindeki küçük favori işareti.
class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.favorite,
        size: 14,
        color: Colors.redAccent,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasBooks});

  final bool hasBooks;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasBooks ? Icons.search_off : Icons.library_books_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasBooks
                  ? 'Aramana uyan kitap yok.'
                  : 'Kitaplığın boş.\nİlk kitabını barkod tarayarak ekle.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (hasBooks)
              Text(
                'Durum çipleriyle daraltabilirsin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

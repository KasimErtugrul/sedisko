import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/book_model.dart';
import '../../domain/services/reading_goal.dart';
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
/// - Arama boşken: özet satırı (toplam / okunuyor / bitti), ardından
///   "Devam eden kitaplar", "Favoriler" (daima görünür; boşken yönlendirme
///   ipucu), "Bitirme hedefleri", "En çok sayfalı kitaplar" ve "Not
///   aldıkların" yatay şeritleri. "Tüm kitaplar" listesi ana sayfadan
///   kaldırıldı: tam kitaplık Raflar sekmesindeki "Tüm kitaplar" kartından
///   açılır.
/// - Arama yazılırken: durum filtresi çipleri + eşleşen kitap listesi.
///
/// Tüm akış `ListView.builder` ile tek sanallaştırılmış listede kurulur;
/// 200+ kitapta yalnız görünür öğeler inşa edilir.
class HomePage extends GetView<LibraryController> {
  const HomePage({super.key});

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

  /// Ana akış: özet + bölüm şeritleri, tek sanallaştırılmış liste.
  ///
  /// "Favoriler" bölümü kitaplıkta favori olmasa bile görünür; boşken
  /// kullanıcıya favorileştirmeyi öğreten ipucu kartı gösterilir.
  /// Diğer bölümler yalnız doluysa listeye girer, yer tutmaz.
  Widget _homeFeed() {
    final reading = controller.readingBooks;
    final favorites = controller.favoriteBooks;
    final goals = controller.goalBooks;
    final longest = controller.longestBooks;
    final noted = controller.notedBooks;

    final sections = <_Section>[
      if (reading.isNotEmpty) _Section('Devam eden kitaplar', reading),
      _Section(
        'Favoriler',
        favorites,
        emptyMessage: 'Henüz favori kitabın yok.\n'
            'Kitap detayındaki kalp ikonuyla favorilerine ekleyebilirsin.',
      ),
      if (goals.isNotEmpty)
        _Section(
          'Bitirme hedefleri',
          goals,
          emphasizeGoal: true,
        ),
      if (longest.isNotEmpty) _Section('En çok sayfalı kitaplar', longest),
      if (noted.isNotEmpty) _Section('Not aldıkların', noted),
    ];

    final itemCount = 1 + sections.length * 2; // özet + her bölüm (başlık+şerit)

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) return _SummaryRow();
        var cursor = 1;
        for (final section in sections) {
          if (index == cursor) return _SectionHeader(section.title);
          if (index == cursor + 1) {
            final empty = section.books.isEmpty;
            if (empty && section.emptyMessage != null) {
              return _SectionEmptyHint(message: section.emptyMessage!);
            }
            return _BookStrip(
              books: section.books,
              emphasizeGoal: section.emphasizeGoal,
            );
          }
          cursor += 2;
        }
        return const SizedBox.shrink();
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
  const _Section(
    this.title,
    this.books, {
    this.emptyMessage,
    this.emphasizeGoal = false,
  });

  final String title;
  final List<BookModel> books;

  /// Bölüm boşken gösterilecek yönlendirme metni; `null` ise boş bölüm
  /// hiç listeye girmez (yer tutmaz).
  final String? emptyMessage;

  /// Şerit kartlarında bitirme hedefi geri sayımının gösterilmesi.
  final bool emphasizeGoal;
}

/// Özet satırı: toplam / okunuyor / bitti sayıları.
class _SummaryRow extends GetView<LibraryController> {
  const _SummaryRow();

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
          stat('${controller.books.length}', 'Toplam', scheme.primary),
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
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    // Baseline hizalı Row yerine tek Text: uzun başlıklar sınırlı genişlikte
    // sarılır, taşma yapmaz.
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Boş bölümün yönlendirme ipucu kartı (ör. favori yokken Favoriler).
class _SectionEmptyHint extends StatelessWidget {
  const _SectionEmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.favorite_outline,
              size: 22,
              color: scheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yatay kapak şeridi; kitaba dokununca detay sayfası açılır.
class _BookStrip extends StatelessWidget {
  const _BookStrip({required this.books, this.emphasizeGoal = false});

  final List<BookModel> books;

  /// true: kart durumu yerine bitirme hedefi geri sayımını gösterir
  /// ("X gün kaldı" / "N gün gecikti").
  final bool emphasizeGoal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 252,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final book = books[index];
          return _BookCoverCard(
            key: ValueKey('strip-${book.id}'),
            book: book,
            emphasizeGoal: emphasizeGoal,
            onTap: () => Get.toNamed(Routes.detail, arguments: book.id),
          );
        },
      ),
    );
  }
}

/// Zengin kapak kartı: kapak + başlık + yazar + durum/sayfa + raf.
/// Hedefli şeritlerde raf satırı yerine geri sayım satırı çıkar.
class _BookCoverCard extends StatelessWidget {
  const _BookCoverCard({
    super.key,
    required this.book,
    required this.onTap,
    this.emphasizeGoal = false,
  });

  final BookModel book;
  final VoidCallback onTap;
  final bool emphasizeGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    return SizedBox(
      width: 116,
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
                    width: 116,
                    height: 150,
                    child: CoverImage(
                      url: book.coverUrl,
                      path: book.coverPath,
                      width: 116,
                      height: 150,
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
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (book.authors.isNotEmpty)
              Text(
                book.authorsText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: small?.copyWith(color: theme.colorScheme.outline),
              ),
            const SizedBox(height: 2),
            Text(
              _statusLine(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small,
            ),
            Text(
              emphasizeGoal
                  ? _goalCountdownLine()
                  : (book.shelf.trim().isEmpty
                      ? 'Rafsız'
                      : 'Raf: ${book.shelf.trim()}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small?.copyWith(
                color: _countdownColor(theme) ?? theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Durum/sayfa satırı: okunuyorsa ilerleme, bittiyse bitiş, başlanmadıysa
  /// sayfa sayısı (bilinmiyorsa durum etiketi).
  String _statusLine() {
    switch (book.status) {
      case ReadingStatus.reading:
        return book.pageCount > 0
            ? 'Sayfa ${book.currentPage}/${book.pageCount}'
            : 'Sayfa ${book.currentPage}';
      case ReadingStatus.finished:
        return 'Bitti • ${formatDate(book.finishedAt)}';
      case ReadingStatus.notStarted:
        return book.pageCount > 0
            ? '${book.pageCount} sayfa'
            : 'Henüz başlanmadı';
    }
  }

  /// Hedef şeridindeki geri sayım satırı.
  String _goalCountdownLine() {
    final target = book.targetFinishDate;
    if (target == null) return '';
    final days = ReadingGoal.daysLeft(target, DateTime.now());
    if (days < 0) return '${-days} gün gecikti';
    if (days == 0) return 'Hedef bugün';
    return '$days gün kaldı';
  }

  Color? _countdownColor(ThemeData theme) {
    if (!emphasizeGoal || book.targetFinishDate == null) return null;
    final days =
        ReadingGoal.daysLeft(book.targetFinishDate!, DateTime.now());
    if (days < 0) return theme.colorScheme.error;
    return null;
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

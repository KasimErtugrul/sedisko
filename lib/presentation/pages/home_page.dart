import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/borrowed_book_model.dart';
import '../../data/models/loan_model.dart';
import '../../data/models/wishlist_item_model.dart';
import '../../domain/services/home_feed.dart';
import '../controllers/library_controller.dart';
import '../controllers/loan_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/shelf_organize_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../utils/app_navigation.dart';
import '../widgets/book_tile.dart';
import '../widgets/home/author_strip.dart';
import '../widgets/home/book_strip.dart';
import '../widgets/home/borrowed_strip.dart';
import '../widgets/home/favorite_author_strip.dart';
import '../widgets/home/home_empty_state.dart';
import '../widgets/home/home_section_header.dart';
import '../widgets/home/home_shortcuts_row.dart';
import '../widgets/home/home_plan_banner.dart';
import '../widgets/home/home_summary_row.dart';
import '../widgets/home/loan_strip.dart';
import '../widgets/home/shelf_summary_grid.dart';
import '../widgets/home/wishlist_strip.dart';
import '../widgets/shelf_picker_sheet.dart';
import '../widgets/status_filter_row.dart';

/// Ana sayfa sekmesi: kitap odaklı, zenginleştirilmiş özet akışı.
///
/// Bu dosya yalnız kompozisyondan sorumludur (tanrı dosyası değil):
/// görsel parçalar `widgets/home/` altında küçük dosyalara bölünmüştür,
/// bölüm verileri [HomeFeed] saf servisinden gelir.
///
/// Arama boşken akış sırası:
/// 1. Özet satırı (toplam / okunuyor / bitti / favori)
/// 2. "Taşıma planı sürüyor" kartı — YALNIZ plan sürerken (1.22.0,
///    keşke 29: "ben Ana Sayfa'da yaşıyorum"); plan yokken yer tutmaz
/// 3. "Kısayollar" satırı — her koşulda duran yazılı düğmeler: Tüm
///    kitaplar / Ödünç verilenler / Ödünç aldıkların / Satın alınacaklar
///    (1.22.0 — keşke 13, 14: "kitap listesini beş dakika aradım",
///    "minik 'Tümü' yazısı gözüme görünmedi bile")
/// 4. "Devam eden kitaplar" — yatay şerit
/// 5. "Favoriler" — yatay şerit
/// 6. "Favori yazarlar" — yıldız avatarlı yazar kartları (1.16.0); asistan
///    kurulumunda seçilen favori yazarlar burada da görünür; "Tümü"
///    Yazarlar sekmesine geçirir
/// 7. "Bitirme hedefleri" — geri sayımlı yatay şerit
/// 8. "Son eklenenler" — eklenme tarihi azalan yatay şerit
/// 9. "En çok sayfalı kitaplar" — yatay şerit
/// 10. "En çok kitaba sahip yazarlar" — yatay yazar kartları; "Tümü"
///    Yazarlar sekmesine geçirir
/// 11. "Rafların" — iki kolonlu raf grid'i (gridview); "Tümü" Raflar
///    sekmesine geçirir
/// 12. "Bu ay bitirdiklerin" — bu ay bitirilenler şeridi
/// 13. "Not aldıkların" — notlu kitaplar şeridi
/// 14. "Ödünç verilenler" — aktif ödünç şeridi (1.18.0); "Tümü" ödünç
///     sayfasını açar
/// 15. "Ödünç aldıkların" — başkasından alınan kitaplar şeridi (1.18.0)
/// 16. "Satın alınacaklar" — satın alma listesi şeridi (1.18.0)
///
/// Hiçbir bölüm veri yokken gizlenmez: her bölüm başlığı her koşulda
/// görünür; veri olmayan bölümün yerinde kısa bir "Henüz ..." ipucu
/// kartı durur (ör. "Henüz favori kitabın yok."). Böylece sayfa düzeni
/// kitaplık durumuna göre oynamaz, kullanıcı bölüm yerini ezberler.
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
      // Kullanıcı isteği (1.16.0): ana sayfa uygulama çubuğunda sırala/
      // filtre aksiyonu YOK — ana akış bölümleri sabit sırayla gelir,
      // sıralamanın burada işi yoktur. Sıralama Raf sayfasındaki
      // "Tüm kitaplar" listesinden yönetilir (bkz. ShelfPage).
      appBar: AppBar(title: const Text('Kitaplığım')),
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
                    // Keşke 3 + 4 (1.23.0): boş durum yönlendirmesi yazı
                    // değil düğmedir — ekle menüsünü açar (FAB'la aynı iş,
                    // aynı ad). Barkod kullanılamıyorsa metin "elle" der.
                    return HomeEmptyState(
                      hasBooks: false,
                      onAdd: () => _showAddSheet(context),
                    );
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

  /// Ana akış: özet + durum kartı + kısayollar + bölüm şeritleri, tek
  /// sanallaştırılmış liste.
  ///
  /// Her bölüm her koşulda listeye girer; veri yokken şerit yerine
  /// [HomeSectionEmptyHint] ipucu kartı kurulur ("Henüz ..." metni).
  /// Bölüm gizlenmez, düzen kitaplık durumuna göre oynamaz.
  ///
  /// Kısayollar satırı bölüm değildir: veriye bağlı olmadığı için her
  /// koşulda girer. Plan hatırlatma kartı ise durum kartıdır: YALNIZ
  /// plan sürerken girer, plan bitince akıştan çekilir (keşke 29). Plan
  /// durumu burada okunur — dış Obx plan değişimine abone olur; kartın
  /// kendi Obx'i de içtaki metni yeniler.
  Widget _homeFeed() {
    final books = controller.books;
    final topAuthors = HomeFeed.topAuthors(books);
    final finishedThisMonth = HomeFeed.finishedThisMonth(books, DateTime.now());
    final shelfSummaries = _shelfSummaries();
    final favoriteAuthors = _favoriteAuthorSummaries();
    final hasPlan = Get.isRegistered<ShelfOrganizeController>() &&
        Get.find<ShelfOrganizeController>().plan.value != null;

    final sections = <_FeedSection>[
      _FeedSection(
        'Devam eden kitaplar',
        BookStrip(books: controller.readingBooks),
        isEmpty: controller.readingBooks.isEmpty,
        emptyMessage: 'Henüz okumaya başladığın kitap yok.\n'
            'Bir kitabı "Okuyorum" olarak işaretlediğinde burada görünür.',
        emptyIcon: Icons.menu_book_outlined,
      ),
      _FeedSection(
        'Favoriler',
        BookStrip(books: controller.favoriteBooks),
        isEmpty: controller.favoriteBooks.isEmpty,
        emptyMessage: 'Henüz favori kitabın yok.\n'
            'Kitap detayındaki kalp ikonuyla favorilerine ekleyebilirsin.',
        emptyIcon: Icons.favorite_outline,
      ),
      // Favori yazarlar (1.16.0): asistan kurulumunda seçilen favori
      // yazarlar ana sayfada da görünür. Denetleyici izole testlerde
      // kayıtlı olmayabilir; o zaman bölüm boş ipucu kartıyla durur.
      _FeedSection(
        'Favori yazarlar',
        FavoriteAuthorStrip(authors: favoriteAuthors),
        isEmpty: favoriteAuthors.isEmpty,
        emptyMessage: 'Henüz favori yazar seçmedin.\n'
            'Raflar sekmesindeki düzen asistanında favori yazarlarını '
            'seçebilirsin.',
        emptyIcon: Icons.star_outline,
        onSeeAll: onOpenAuthors,
        actionKey: const ValueKey('see-all-favorite-authors'),
        // Keşke 4 (1.23.0): ipucu Raflar sekmesini gösteriyorsa o
        // sekmeyi açan düğme de taşır (ulaşılan tek "raf sekmesi"
        // yönlendirmesi; 'Rafların' bölümündeki aynı adlı aksiyonla
        // tek hedefi paylaşır — aynı iş, aynı ad).
        hintActionLabel:
            onOpenShelves == null ? null : 'Raflar sekmesine git',
        hintAction: onOpenShelves,
        hintActionKey: const ValueKey('hint-open-shelves'),
      ),
      _FeedSection(
        'Bitirme hedefleri',
        BookStrip(books: controller.goalBooks, emphasizeGoal: true),
        isEmpty: controller.goalBooks.isEmpty,
        emptyMessage: 'Henüz bitirme hedefi koyduğun kitap yok.\n'
            'Kitap detayından "Bitirme hedefi" tarihi seçebilirsin.',
        emptyIcon: Icons.flag_outlined,
      ),
      _FeedSection(
        'Son eklenenler',
        BookStrip(books: HomeFeed.recentlyAdded(books)),
        isEmpty: books.isEmpty,
        emptyMessage: 'Henüz kitap eklemedin.\n'
            'Sağ alttaki "Kitap ekle" düğmesiyle başlayabilirsin.',
        emptyIcon: Icons.schedule_outlined,
      ),
      _FeedSection(
        'En çok sayfalı kitaplar',
        BookStrip(books: controller.longestBooks),
        isEmpty: controller.longestBooks.isEmpty,
        emptyMessage: 'Henüz sayfa sayısı girilmiş kitap yok.\n'
            'Kitap detayından sayfa sayısını girebilirsin.',
        emptyIcon: Icons.format_list_numbered_outlined,
      ),
      _FeedSection(
        'En çok kitaba sahip yazarlar',
        AuthorStrip(authors: topAuthors),
        isEmpty: topAuthors.isEmpty,
        emptyMessage: 'Henüz yazar bilgisi girilmiş kitap yok.\n'
            'Kitap detayından yazar ekleyebilirsin.',
        emptyIcon: Icons.person_outline,
        onSeeAll: onOpenAuthors,
        actionKey: const ValueKey('see-all-authors'),
      ),
      _FeedSection(
        'Rafların',
        ShelfSummaryGrid(shelves: shelfSummaries, onOpen: _openShelf),
        isEmpty: shelfSummaries.isEmpty,
        emptyMessage: 'Henüz raf oluşturmadın.\n'
            'Raflar sekmesinden raf ekleyebilirsin.',
        emptyIcon: Icons.bookmark_outline,
        onSeeAll: onOpenShelves,
        actionKey: const ValueKey('see-all-shelves'),
        // Keşke 4 (1.23.0): yönlendirme yazısı basılabilir düğmedir.
        // Not: kitap varken 'Rafsız' kartı her zaman durduğu için bu
        // ipucu pratikte çizilmez; aksiyon aynı adla 'Favori yazarlar'
        // ipucunda ulaşılandır. İki ipucu asla aynı anda kurulmaz
        // (ikisi de yalnız kitaplık tamamen boşken boşalır ve o zaman
        // akışın yerine HomeEmptyState geçer).
        hintActionLabel:
            onOpenShelves == null ? null : 'Raflar sekmesine git',
        hintAction: onOpenShelves,
        hintActionKey: const ValueKey('hint-open-shelves'),
      ),
      _FeedSection(
        'Bu ay bitirdiklerin',
        BookStrip(books: finishedThisMonth),
        isEmpty: finishedThisMonth.isEmpty,
        emptyMessage: 'Bu ay henüz bitirdiğin kitap yok.\n'
            'Bitirdiğin kitaplar ay değiştikçe burada toplanır.',
        emptyIcon: Icons.celebration_outlined,
      ),
      _FeedSection(
        'Not aldıkların',
        BookStrip(books: controller.notedBooks),
        isEmpty: controller.notedBooks.isEmpty,
        emptyMessage: 'Henüz not aldığın kitap yok.\n'
            'Kitap detayından not ekleyebilirsin.',
        emptyIcon: Icons.notes_outlined,
      ),
      // Ödünç verme (1.18.0): kitaplıkta bir kitabın kişiye verilmesi.
      // Denetleyici izole testlerde kayıtlı olmayabilir; o zaman bölüm
      // boş ipucu kartıyla durur (bölüm asla gizlenmez).
      _FeedSection(
        'Ödünç verilenler',
        LoanStrip(
          loans: _activeLoans(),
          onTapLoan: (loan) =>
              Get.toNamed(Routes.detail, arguments: loan.bookId),
        ),
        isEmpty: _activeLoans().isEmpty,
        emptyMessage: 'Henüz ödünç verilen kitap yok.\n'
            'Kitap detayındaki "Ödünç ver" aksiyonunu kullanabilirsin.',
        emptyIcon: Icons.book_outlined,
        onSeeAll: () => Get.toNamed(Routes.loans),
        actionKey: const ValueKey('see-all-loans'),
      ),
      // Ödünç alma (1.18.0): başkasından alınan, kitaplıkta olmayan kitaplar.
      _FeedSection(
        'Ödünç aldıkların',
        BorrowedStrip(
          borrowed: _activeBorrowed(),
          onTap: (_) => Get.toNamed(Routes.borrowed),
        ),
        isEmpty: _activeBorrowed().isEmpty,
        emptyMessage: 'Başkasından aldığın kitap yok.\n'
            '"Tümü" sayfasından ödünç aldığın kitabı ekleyebilirsin.',
        emptyIcon: Icons.swap_horiz_outlined,
        onSeeAll: () => Get.toNamed(Routes.borrowed),
        actionKey: const ValueKey('see-all-borrowed'),
      ),
      // Satın alınacaklar (1.18.0): Open Library aramasından ya da elle
      // eklenen, alınmak istenen kitaplar.
      _FeedSection(
        'Satın alınacaklar',
        WishlistStrip(
          items: _wishlistItems(),
          onTapItem: (_) => Get.toNamed(Routes.wishlist),
        ),
        isEmpty: _wishlistItems().isEmpty,
        emptyMessage: 'Satın alınacak kitap listen boş.\n'
            '"Tümü" sayfasından Open Library aramasıyla ya da elle '
            'ekleyebilirsin.',
        emptyIcon: Icons.shopping_cart_outlined,
        onSeeAll: () => Get.toNamed(Routes.wishlist),
        actionKey: const ValueKey('see-all-wishlist'),
      ),
    ];

    // Özet + (varsa plan kartı) + kısayollar + her bölüm (başlık+şerit).
    final itemCount =
        1 + (hasPlan ? 1 : 0) + 1 + sections.length * 2;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) return const HomeSummaryRow();
        var cursor = 1;
        if (hasPlan) {
          if (index == cursor) return const HomePlanBanner();
          cursor++;
        }
        if (index == cursor) return const HomeShortcutsRow();
        cursor++;
        for (final section in sections) {
          if (index == cursor) return _sectionHeader(section);
          if (index == cursor + 1) {
            if (section.isEmpty) {
              return HomeSectionEmptyHint(
                message: section.emptyMessage,
                icon: section.emptyIcon,
                actionLabel: section.hintActionLabel,
                onAction: section.hintAction,
                actionKey: section.hintActionKey,
              );
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

  /// Kullanıcının favori yazarları; asistan denetleyicisinden okunur.
  /// Denetleyici kayıtlı değilse boş liste: bölüm ipucu kartıyla durur.
  List<AuthorSummary> _favoriteAuthorSummaries() {
    if (!Get.isRegistered<ShelfOrganizeController>()) {
      return const <AuthorSummary>[];
    }
    final organize = Get.find<ShelfOrganizeController>();
    return HomeFeed.favoriteAuthorSummaries(
      controller.books,
      organize.favoriteAuthors.toList(),
    );
  }

  /// Aktif ödünç verilenler (en yeni önce, en fazla 10 kart).
  /// Denetleyici kayıtlı değilse boş liste.
  List<LoanModel> _activeLoans() {
    if (!Get.isRegistered<LoanController>()) return const <LoanModel>[];
    return Get.find<LoanController>().activeLoans.take(10).toList();
  }

  /// Aktif ödünç alınanlar (en yeni önce, en fazla 10 kart).
  List<BorrowedBookModel> _activeBorrowed() {
    if (!Get.isRegistered<LoanController>()) {
      return const <BorrowedBookModel>[];
    }
    return Get.find<LoanController>().activeBorrowed.take(10).toList();
  }

  /// Satın alınacaklar (en yeni önce, en fazla 10 kart).
  List<WishlistItemModel> _wishlistItems() {
    if (!Get.isRegistered<WishlistController>()) {
      return const <WishlistItemModel>[];
    }
    return Get.find<WishlistController>().items.take(10).toList();
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
              leading: const Icon(Icons.travel_explore),
              title: const Text('İsim/yazarla ara'),
              subtitle: const Text(
                "Open Library'de kitap adı veya yazarla ara",
              ),
              onTap: () {
                AppNav.pop();
                Get.toNamed(Routes.search);
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
    required this.isEmpty,
    required this.emptyMessage,
    this.emptyIcon,
    this.onSeeAll,
    this.actionKey,
    this.hintActionLabel,
    this.hintAction,
    this.hintActionKey,
  });

  final String title;
  final Widget body;

  /// Bölüm verisinin boşluğu; boşsa şerit yerine ipucu kartı kurulur.
  /// Veri listesi `_homeFeed` içinde hesaplanır, karar buraya taşınır.
  final bool isEmpty;

  /// Boşken gösterilen "Henüz ..." ipucu metni; her bölümde bulunur
  /// (bölüm asla gizlenmez).
  final String emptyMessage;

  /// İpucu kartının altındaki yazılı aksiyon (keşke 4, 1.23.0): ipucu
  /// bir yere yönlendiriyorsa o yeri açan düğme. Yalnız 'Rafların'
  /// bölümünde kullanılır (kabuk dışında null — aksiyon gizlenir).
  final String? hintActionLabel;
  final VoidCallback? hintAction;
  final Key? hintActionKey;

  /// İpucu kartının sembolü (bölüm konusuna uyan ikon).
  final IconData? emptyIcon;

  /// Başlığın sağındaki "Tümü" aksiyonu (null ise aksiyon gizlenir).
  final VoidCallback? onSeeAll;
  final Key? actionKey;
}

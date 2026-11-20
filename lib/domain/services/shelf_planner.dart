import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';
import '../../data/models/shelf_model.dart';
import 'book_sort.dart';
import 'book_thickness.dart';
import 'organize_criterion.dart';
import 'organize_options.dart';

/// Planlanan tek raf: raf tanımı + o rafa yerleştirilen kitaplar.
/// Kitap sırası, fiziksel diziliş sırasıdır (grup modunda yerleştirme
/// sırası, akış modunda alfabe/kalınlık sırası).
///
/// **1.19.0:** doluluk MILIMETRE cinsindendir — rafın bütçesi
/// `lengthCm × 10`, kitabın yeri sayfa sayısından hesaplanan kalınlıktır
/// (420 sayfa ≈ 3 cm, 130 sayfa ≈ 1 cm).
class PlannedShelf extends Equatable {
  const PlannedShelf({
    required this.shelf,
    required this.books,
  });

  final ShelfModel shelf;
  final List<BookModel> books;

  int get count => books.length;

  /// Plandaki kitapların toplam kapladığı yer, milimetre.
  int get usedMm => books.fold(
        0,
        (sum, book) => sum + BookThickness.mmOf(book.pageCount),
      );

  /// Rafın toplam yer bütçesi, milimetre (uzunluk cm × 10).
  int get capacityMm => shelf.lengthMm;

  @override
  List<Object?> get props => [shelf, books];
}

/// Hedef düzen: hangi kitabın hangi rafta olacağı.
///
/// Taşma kuralı kesindir: hiçbir raf uzunluğunun üzerine çıkmaz.
/// Her kitabın ya bir hedefi vardır ya da [unplaced] listesinde bekler
/// (kapasite hiç yetmediyse) — "eksik kitap" olamaz, "plansız kitap"
/// olabilir ve kullanıcıya açıkça bildirilir.
class ShelfArrangement {
  ShelfArrangement({
    required this.shelves,
    this.warnings = const [],
    this.unplaced = const [],
  }) {
    _targets = <String, String>{
      for (final planned in shelves)
        for (final book in planned.books) book.id: planned.shelf.name,
    };
  }

  final List<PlannedShelf> shelves;
  final List<String> warnings;
  final List<BookModel> unplaced;

  late final Map<String, String> _targets;

  /// [bookId] kitabının planlanan raf adı; plan dışıysa `null`.
  String? targetShelfOf(String bookId) => _targets[bookId];

  int get totalPlannedCount =>
      shelves.fold(0, (sum, planned) => sum + planned.count);
}

/// Hedef düzeni üreten saf servis.
///
/// Kurallar (kullanıcı kararlarıyla sabitlendi):
/// - **Yazar asla bölünmez (1.17.0 — kullanıcı kuralı):** "kesinlikle ama
///   kesinlikle yazarlara göre talep edilmişse sırf favori rafa sığmıyor
///   diye başka raflara yazarları bölme; az olsun ama yazarları bölme."
///   Yazara göre düzende her yazarın kitapları ATOMİKTİR: yazar ya tek
///   rafa bütün halinde gider ya da hiçbir rafa sığmıyorsa bütün halinde
///   "Karışık kitaplar" rafına. Yer yetmediğinde raf eksik dolar (örn.
///   125 cm'lik favori raf 100 cm'de kalır); yazar ikiye asla bölünmez.
/// - **Favoriler yalnız "Yazara göre"dedir (1.19.0 — kullanıcı kararı):**
///   favori raf + favori yazarlar tercihi YALNIZCA kriter "Yazara göre"
///   seçiliyken çalışır; favori yazarların grupları kullanıcının
///   listediği sırayla favori rafa BÜTÜN halinde yerleşir. Favori rafa
///   sığmayan favori yazar bölünmez: grup tek parça olarak ilk sığan
///   başka rafa gider; hiçbir rafa sığmıyorsa Karışık kitaplar rafına.
///   Favori raf YALNIZCA favori yazarların kitaplarını tutar; kalan boşluk
///   diğer kitaplara açılmaz (favori yazarların olası yeni kitapları için
///   ayrılıdır) ve uyarıyla bildirilir. Yayınevi / kitap adı / sayfa
///   sayısı düzenlemeleri favorilerden TAMAMEN bağımsızdır.
/// - **cm modeli (1.19.0):** raf bütçesi kullanıcının girdiği UZUNLUK
///   (cm × 10 mm), kitabın yeri sayfa sayısından hesaplanan kalınlıktır
///   (420 sayfa ≈ 3 cm, 130 sayfa ≈ 1 cm; bilinmeyen ≈ 2,5 cm).
/// - **Grup modu (yazar / yayınevi):** gruplar kitap sayısı çoktan aza
///   sıralanır (eşitlikte Türkçe alfabe); her grup BÜTÜN halinde ilk
///   sığan rafa yerleşir (first-fit). Yazar grupları hiçbir koşulda
///   bölünmez (yukarıdaki kural).
/// - **Taşan yayınevi grubu:** grubun yeri en uzun rafın bütçesini
///   aşıyorsa rafa sığan kadarı konur (kitap sırasıyla), artık
///   "Karışık kitaplar" rafına gider. Bu bölme YALNIZ yayınevi ve
///   yazarsız kitaplar içindir; yazar gruplerine uygulanmaz (1.17.0).
///   Raf alanı hiç kalmayan yayınevi grubu ise bütün halinde Karışık'a
///   gider.
/// - **Akış modu (kitap adı / sayfa sayısı):** kitaplar tek sıraya dizilir
///   (BookSorter: eksik bilgi sonda), raflar fiziksel sırayla baştan
///   doldurulur; sıradaki kitap artık sığmıyorsa sıradaki rafa geçilir —
///   fiziksel kitaplık gibi (sıra bozulmaz). Sığmayanlar "Karışık
///   kitaplar" rafına gider.
/// - **Karışık raf:** artıklar için adı geçen gerçek raf varsa bütün
///   yazar grupları TAMAMININ sığması koşuluyla konur (sığmayan yazar
///   grubu olduğu yerde bırakılır ve plan dışı bildirilir); yazarı
///   olmayan artıklar tek tek doldurulur. Gerçek raf yoksa plan sentetik
///   bir "Karışık kitaplar" rafı ekler (uzunluğu tam artıklara eşittir).
/// - **Kararlılık:** aynı girdiden her zaman aynı plan çıkar (tüm
///   eşitlik kırıcıları: Türkçe alfabe → kitap adı → id).
abstract final class ShelfPlanner {
  static ShelfArrangement arrange(
    List<BookModel> books,
    List<ShelfModel> shelves,
    OrganizeCriterion criterion, {
    OrganizeOptions options = const OrganizeOptions(),
  }) {
    final ordered = [...shelves]..sort((a, b) => a.order.compareTo(b.order));

    final emptyShelves = [
      for (final shelf in ordered)
        PlannedShelf(
          shelf: shelf,
          books: const [],
        ),
    ];
    if (books.isEmpty) {
      return ShelfArrangement(shelves: emptyShelves);
    }
    if (ordered.isEmpty) {
      return ShelfArrangement(
        shelves: const [],
        warnings: [
          'Henüz raf tanımlanmamış. Önce raflarını ekleyip cm '
          'uzunluklarını gir.',
        ],
        unplaced: books,
      );
    }

    final warnings = <String>[];
    final buckets = List<List<BookModel>>.generate(ordered.length, (_) => []);

    // Yer bütçeleri milimetre: raf uzunluğu (cm × 10), kitabın yeri
    // sayfa sayısından hesaplanan kalınlık.
    final remaining = [for (final shelf in ordered) shelf.lengthMm];

    // Serbest artıklar (tek tek konabilir: yazarsız kitaplar, akış modu
    // artıkları, yayınevi artıkları) ve ATOMİK artıklar (bütün yazar
    // grupları — tamamı bir arada konur ya da hiç konmaz).
    final freeLeftovers = <BookModel>[];
    final atomicLeftovers = <_BookGroup>[];

    // Kitap havuzu: favori yazarların yerleşen kitapları çıkarılır.
    var pool = books;

    // 1) Favori yazarlar → favori raf. YALNIZ "Yazara göre" kriterinde
    //    devreye girer (1.19.0 kullanıcı kararı): öteki kriterler kendi
    //    başlarına, favorilerden bağımsız çalışır.
    final useFavorites =
        criterion == OrganizeCriterion.author && options.hasFavorites;
    if (useFavorites) {
      final favIndex =
          ordered.indexWhere((shelf) => shelf.id == options.favoriteShelfId);
      if (favIndex >= 0) {
        final favGroups =
            _favoriteAuthorGroups(books, options.favoriteAuthors);
        for (final group in favGroups) {
          final weight = _weightMm(group.books);
          if (remaining[favIndex] >= weight) {
            // Bütün grup favori rafa sığıyor.
            buckets[favIndex].addAll(group.books);
            remaining[favIndex] -= weight;
            continue;
          }
          // Bütün grup favori rafa sığmıyor: yazar BÖLÜNMEZ. Grup tek
          // parça olarak ilk sığan başka rafa gider; hiçbir rafa
          // sığmıyorsa Karışık kitaplar rafına.
          final target = remaining.indexWhere((space) => space >= weight);
          if (target >= 0) {
            buckets[target].addAll(group.books);
            remaining[target] -= weight;
            warnings.add(
              '«${group.display}» yazarının ${group.books.length} kitabı '
              'favori rafa bir bütün olarak sığmadı; yazar bölünmedi — '
              'kitaplar ${ordered[target].name} rafına konuyor.',
            );
          } else {
            atomicLeftovers.add(group);
            warnings.add(
              '«${group.display}» yazarının ${group.books.length} kitabı '
              'favori rafa bir bütün olarak sığmadı ve hiçbir rafta tek '
              'parça yer kalmadı; "${ShelfModel.mixShelfName}" rafına '
              'konuyor.',
            );
          }
        }
        if (remaining[favIndex] > 0) {
          warnings.add(
            '${ordered[favIndex].name} rafı yalnızca favori yazarların '
            'kitaplarını tutar; kalan ${BookThickness.formatMm(
              remaining[favIndex],
            )} yer favori yazarlar dışındaki kitaplara açılmadı.',
          );
        }
        // Favori rafın kalan boşluğu rezerve edilir: genel dağıtım bu
        // rafa hiçbir kitap koymaz.
        remaining[favIndex] = 0;
        // Favori yazarlara uyan TÜM kitaplar havuzdan çıkarılır: her
        // biri favori aşamasında ya yerleşti ya bütün halinde bir
        // artık listesine girdi; genel dağıtım bunlara dokunmaz
        // (bölünme ve çift yerleşme olmaz).
        final favoriteIds = <String>{
          for (final group in favGroups)
            for (final book in group.books) book.id,
        };
        pool = books.where((book) => !favoriteIds.contains(book.id)).toList();
      }
    }

    if (criterion.isGrouped) {
      _placeByGroups(
        books: pool,
        criterion: criterion,
        ordered: ordered,
        remaining: remaining,
        buckets: buckets,
        freeLeftovers: freeLeftovers,
        atomicLeftovers: atomicLeftovers,
        warnings: warnings,
      );
    } else {
      _placeAsStream(
        books: pool,
        criterion: criterion,
        ordered: ordered,
        remaining: remaining,
        buckets: buckets,
        freeLeftovers: freeLeftovers,
        warnings: warnings,
      );
    }

    return _finalize(
      ordered: ordered,
      buckets: buckets,
      remaining: remaining,
      freeLeftovers: freeLeftovers,
      atomicLeftovers: atomicLeftovers,
      warnings: warnings,
    );
  }

  // ---------- Favori yazarlar ----------

  /// Favori yazarların kitaplarını ATOMİK gruplar halinde döner: gruplar
  /// kullanıcının listediği sıradadır; her grup tek bir yazarın bütün
  /// kitaplarıdır (grup içi sıra kitap adı, eşitlikte id). Bir kitap
  /// birden çok favori yazara uyuyorsa İLK yazara verilir (tekrar yok).
  static List<_BookGroup> _favoriteAuthorGroups(
    List<BookModel> books,
    List<String> favoriteAuthors,
  ) {
    final groups = <_BookGroup>[];
    final seen = <String>{};
    for (final raw in favoriteAuthors) {
      final name = raw.trim();
      final key = TextNormalizer.searchKey(name);
      if (key.isEmpty) continue;
      final group = _BookGroup(key: key, display: name);
      for (final book in books) {
        if (seen.contains(book.id)) continue;
        final matches = book.authors.any(
          (author) => TextNormalizer.searchKey(author.trim()) == key,
        );
        if (matches) group.books.add(book);
      }
      if (group.books.isEmpty) continue;
      group.books.sort((a, b) {
        final byTitle = TextNormalizer.compareTr(a.title, b.title);
        if (byTitle != 0) return byTitle;
        return a.id.compareTo(b.id);
      });
      for (final book in group.books) {
        seen.add(book.id);
      }
      groups.add(group);
    }
    return groups;
  }

  // ---------- Grup modu ----------

  static void _placeByGroups({
    required List<BookModel> books,
    required OrganizeCriterion criterion,
    required List<ShelfModel> ordered,
    required List<int> remaining,
    required List<List<BookModel>> buckets,
    required List<BookModel> freeLeftovers,
    required List<_BookGroup> atomicLeftovers,
    required List<String> warnings,
  }) {
    final groups = _groupsOf(books, criterion);
    final maxBudget =
        ordered.map((shelf) => shelf.lengthMm).reduce(max);
    final maxCm = ordered.map((shelf) => shelf.lengthCm).reduce(max);
    final authorMode = criterion == OrganizeCriterion.author;

    for (final group in groups) {
      final size = group.books.length;
      final weight = _weightMm(group.books);
      // Yazar grupları atomiktir; yazarsız ve yayınevi grupları serbest
      // davranır (1.17.0 kullanıcı kuralı yalnız yazarlar içindir).
      final atomic = authorMode && group.key.isNotEmpty;

      // Bütün grup, fiziksel sıraya göre ilk sığan rafa yerleşir.
      if (weight <= maxBudget) {
        final index = remaining.indexWhere((space) => space >= weight);
        if (index >= 0) {
          buckets[index].addAll(group.books);
          remaining[index] -= weight;
          continue;
        }
        // Raflarda toplam boşluk yetmiyor; grup bölünmez, Karışık'a.
        if (atomic) {
          warnings.add(
            '«${group.display}» yazarının $size kitabı için raf alanı '
            'kalmadı; yazar bölünmedi — tüm kitaplar '
            '"${ShelfModel.mixShelfName}" rafına konuyor.',
          );
          atomicLeftovers.add(group);
        } else {
          warnings.add(
            '"${group.display}" grubunun $size kitabı için raf alanı '
            'kalmadı; "${ShelfModel.mixShelfName}" rafına konuyor.',
          );
          freeLeftovers.addAll(group.books);
        }
        continue;
      }

      // Grup hiçbir rafın bütçesine sığmıyor. Yazar bölünmez: bütün
      // grup Karışık'a gider (1.17.0 kullanıcı kuralı). Yayınevi ve
      // yazarsız gruplarda eski davranış sürer: sığan kadarı konur,
      // artık Karışık'a gider.
      if (atomic) {
        warnings.add(
          '«${group.display}» yazarının $size kitabı tek rafın '
          'uzunluğunu ($maxCm cm) aşıyor; yazar bölünmedi — tüm kitaplar '
          '"${ShelfModel.mixShelfName}" rafına konuyor.',
        );
        atomicLeftovers.add(group);
        continue;
      }

      // Taşan yayınevi/yazarsız grup: önce tamamen boş bir raf (sıra
      // düzeninde ilk), o da yoksa en çok boşluğu olan raf; sığan
      // kadarı buraya (kitap sırası korunur, sığmayan küçük kitap
      // bekletilmez), artık Karışık'a gider. Grup ikiye "bölünmez" —
      // sığmayan kısmın yeri tek ve bellidir.
      final index = _widestIndex(remaining, ordered);
      var taken = 0;
      final rest = <BookModel>[];
      for (final book in group.books) {
        final cost = BookThickness.mmOf(book.pageCount);
        if (remaining[index] >= cost) {
          buckets[index].add(book);
          remaining[index] -= cost;
          taken++;
        } else {
          rest.add(book);
        }
      }
      freeLeftovers.addAll(rest);
      warnings.add(
        '${group.display} grubunun $size kitabı '
        '${BookThickness.formatMm(weight)} yer istiyor; en uzun raf '
        '$maxCm cm. Sığan $taken kitap ${ordered[index].name} rafına, '
        'kalan ${size - taken} kitap "${ShelfModel.mixShelfName}" rafına '
        'konuyor.',
      );
    }
  }

  /// Kitap listesinin toplam kapladığı yer (milimetre).
  static int _weightMm(List<BookModel> books) => books.fold(
        0,
        (sum, book) => sum + BookThickness.mmOf(book.pageCount),
      );

  /// Grupları üretir: anahtar + görünen ad + üyeler. Çoktan aza,
  /// eşitlikte Türkçe alfabe; grup içi sıra kitap adı (eşitlikte id).
  static List<_BookGroup> _groupsOf(
    List<BookModel> books,
    OrganizeCriterion criterion,
  ) {
    final byKey = <String, _BookGroup>{};
    for (final book in books) {
      final (key, display) = criterion == OrganizeCriterion.author
          ? _authorKeyOf(book)
          : _publisherKeyOf(book);
      final group = byKey.putIfAbsent(
        key,
        () => _BookGroup(key: key, display: display),
      );
      group.books.add(book);
    }

    final groups = byKey.values.toList();
    groups.sort((a, b) {
      final bySize = b.books.length.compareTo(a.books.length);
      if (bySize != 0) return bySize;
      return TextNormalizer.compareTr(a.display, b.display);
    });
    for (final group in groups) {
      group.books.sort((a, b) {
        final byTitle = TextNormalizer.compareTr(a.title, b.title);
        if (byTitle != 0) return byTitle;
        return a.id.compareTo(b.id);
      });
    }
    return groups;
  }

  /// Çok yazarlı kitaplarda grup birincil (ilk) yazara göredir; yazarı
  /// olmayanlar tek "Yazarsız" grubunda toplanır.
  static (String, String) _authorKeyOf(BookModel book) {
    for (final raw in book.authors) {
      final author = raw.trim();
      if (author.isNotEmpty) {
        return (TextNormalizer.searchKey(author), author);
      }
    }
    return ('', 'Yazarsız');
  }

  static (String, String) _publisherKeyOf(BookModel book) {
    final publisher = (book.publisher ?? '').trim();
    if (publisher.isEmpty) return ('', 'Yayınevi bilinmiyor');
    return (TextNormalizer.searchKey(publisher), publisher);
  }

  // ---------- Akış modu ----------

  static void _placeAsStream({
    required List<BookModel> books,
    required OrganizeCriterion criterion,
    required List<ShelfModel> ordered,
    required List<int> remaining,
    required List<List<BookModel>> buckets,
    required List<BookModel> freeLeftovers,
    required List<String> warnings,
  }) {
    final sorted = [...books];
    BookSorter.sort(
      sorted,
      criterion == OrganizeCriterion.title
          ? BookSortField.title
          : BookSortField.pageCount,
      true,
    );

    // Fiziksel kitaplık gibi: kitaplar sırayla dizer, sıradaki kitap
    // artık sığmıyorsa sıradaki rafa geçilir (sıra bozulmaz).
    var cursor = 0;
    for (var i = 0; i < ordered.length && cursor < sorted.length; i++) {
      while (cursor < sorted.length) {
        final cost = BookThickness.mmOf(sorted[cursor].pageCount);
        if (remaining[i] < cost) break;
        buckets[i].add(sorted[cursor]);
        remaining[i] -= cost;
        cursor++;
      }
    }
    if (cursor < sorted.length) {
      freeLeftovers.addAll(sorted.getRange(cursor, sorted.length));
      warnings.add(
        'Toplam raf alanı yetmedi: ${sorted.length - cursor} kitap '
        '"${ShelfModel.mixShelfName}" rafına konuyor.',
      );
    }
  }

  // ---------- Karışık rafı ve sonuç ----------

  static ShelfArrangement _finalize({
    required List<ShelfModel> ordered,
    required List<List<BookModel>> buckets,
    required List<int> remaining,
    required List<BookModel> freeLeftovers,
    required List<_BookGroup> atomicLeftovers,
    required List<String> warnings,
  }) {
    final planned = <PlannedShelf>[
      for (var i = 0; i < ordered.length; i++)
        PlannedShelf(
          shelf: ordered[i],
          books: buckets[i],
        ),
    ];

    if (freeLeftovers.isEmpty && atomicLeftovers.isEmpty) {
      return ShelfArrangement(shelves: planned, warnings: warnings);
    }

    final mixKey = TextNormalizer.searchKey(ShelfModel.mixShelfName);
    final existingIndex = ordered
        .indexWhere((shelf) => TextNormalizer.searchKey(shelf.name) == mixKey);

    if (existingIndex >= 0) {
      // Kullanıcının gerçek "Karışık kitaplar" rafı.
      final extra = <BookModel>[];
      final unplaced = <BookModel>[];

      // 1) Bütün yazar grupları: TAMAMI sığıyorsa konur; sığmıyorsa
      //    grubun HİÇBİR kitabı konmaz (yazar bölünmez) ve kitaplar
      //    mevcut yerlerinde bırakılarak açıkça bildirilir.
      for (final group in atomicLeftovers) {
        final weight = _weightMm(group.books);
        if (remaining[existingIndex] >= weight) {
          extra.addAll(group.books);
          remaining[existingIndex] -= weight;
        } else {
          unplaced.addAll(group.books);
          warnings.add(
            '«${group.display}» yazarının ${group.books.length} kitabı '
            '"${ShelfModel.mixShelfName}" rafına da bir bütün olarak '
            'sığmadı; kitaplar mevcut yerlerinde bırakıldı. Yeni raf '
            'ekleyip yeniden planla.',
          );
        }
      }

      // 2) Yazarı olmayan serbest artıklar bütçeye saygılı tek tek
      //    doldurulur; sığmayanlar plan dışı kalır.
      var space = remaining[existingIndex];
      final rest = <BookModel>[];
      for (final book in freeLeftovers) {
        final cost = BookThickness.mmOf(book.pageCount);
        if (space >= cost) {
          extra.add(book);
          space -= cost;
        } else {
          rest.add(book);
        }
      }
      if (rest.isNotEmpty) {
        warnings.add(
          '${rest.length} kitap için "${ShelfModel.mixShelfName}" '
          'rafında da yer kalmadı; bu kitaplar plan dışı kaldı. '
          'Yeni raf ekleyip yeniden planla.',
        );
        unplaced.addAll(rest);
      }

      if (extra.isNotEmpty) {
        planned[existingIndex] = PlannedShelf(
          shelf: ordered[existingIndex],
          books: [...buckets[existingIndex], ...extra],
        );
      }
      if (unplaced.isNotEmpty) {
        return ShelfArrangement(
          shelves: planned,
          warnings: warnings,
          unplaced: unplaced,
        );
      }
      return ShelfArrangement(shelves: planned, warnings: warnings);
    }

    // Sentetik Karışık rafı: uzunluğu tam artıklara eşittir (kendisi
    // hiçbir zaman taşmaz; bütün yazar grupları da sığar). Uzunluk,
    // artıkların toplam yerinin üst tam santimetresidir.
    final allLeftovers = [
      for (final group in atomicLeftovers) ...group.books,
      ...freeLeftovers,
    ];
    final totalMm = _weightMm(allLeftovers);
    final syntheticCm = (totalMm + 9) ~/ 10;
    planned.add(PlannedShelf(
      shelf: ShelfModel(
        id: 'plan-karisik-kitaplar',
        name: ShelfModel.mixShelfName,
        lengthCm: syntheticCm < 1 ? 1 : syntheticCm,
        location: '',
        order: ordered.length,
      ),
      books: allLeftovers,
    ));
    return ShelfArrangement(shelves: planned, warnings: warnings);
  }

  /// Taşan yayınevi/yazarsız grup için hedef raf: tamamen boş raf (sıra
  /// düzeninde ilk) ya da en çok boşluğu olan raf. İkisi de yoksa ilk raf
  /// (kalan yer 0; tüm kitaplar Karışık'a gider).
  static int _widestIndex(List<int> remaining, List<ShelfModel> ordered) {
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i] == ordered[i].lengthMm && remaining[i] > 0) {
        return i;
      }
    }
    var best = 0;
    for (var i = 1; i < remaining.length; i++) {
      if (remaining[i] > remaining[best]) best = i;
    }
    return best;
  }
}

/// Dahili grup toplama.
class _BookGroup {
  _BookGroup({required this.key, required this.display});

  final String key;
  final String display;
  final List<BookModel> books = [];
}

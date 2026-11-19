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
class PlannedShelf extends Equatable {
  const PlannedShelf({
    required this.shelf,
    required this.books,
    this.thicknessAware = false,
  });

  final ShelfModel shelf;
  final List<BookModel> books;

  /// true: doluluk YER (birim) cinsinden hesaplanır — kitabın kapladığı
  /// yer sayfa sayısından gelir (1.15.0). false: kitap sayısı.
  final bool thicknessAware;

  int get count => books.length;

  /// Plandaki kitapların toplam kapladığı yer, yarım birim cinsinden.
  int get usedHalfUnits => books.fold(
        0,
        (sum, book) => sum + BookThickness.costHalfUnits(
              book.pageCount,
              thicknessAware: thicknessAware,
            ),
      );

  /// Rafın toplam yer bütçesi, yarım birim cinsinden (kapasite = kitap
  /// sayısı kalibrasyonu; 1 normal kitap = 1 birim).
  int get capacityHalfUnits => shelf.capacity * 2;

  @override
  List<Object?> get props => [shelf, books, thicknessAware];
}

/// Hedef düzen: hangi kitabın hangi rafta olacağı.
///
/// Taşma kuralı kesindir: hiçbir raf kapasitesinin üzerine çıkmaz.
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
/// - **Favoriler (1.15.0):** favori raf + favori yazarlar birlikte
///   seçildiyse plan favori yazarların kitaplarını EN ÖNCE favori rafa
///   yerleştirir (yazarlar kullanıcının listediği sırayla, kitaplar
///   adına göre; sığmayanlar normal dağıtıma kalır ve uyarılır). Kalan
///   kitaplar seçilen kriterle, favori rafın kalan boşluğu da normal
///   dağıtıma açıktır.
/// - **Kalınlık (1.15.0):** kalınlık hesabı açıksa kapasite YER (birim)
///   cinsindendir: rafın kitap kapasitesi birim bütçesine dönüşür
///   (1 kitap kapasitesi = 1 birim ≈ 350 sayfa), kitap ise sayfa
///   sayısına göre 0,5 birimlik adımlarla yer kaplar. Hesap kapalıyken
///   her kitap 1 birimdir — eski kitap sayısı davranışı birebir korunur.
/// - **Grup modu (yazar / yayınevi):** gruplar kitap sayısı çoktan aza
///   sıralanır (eşitlikte Türkçe alfabe); her grup BÜTÜN halinde ilk
///   sığan rafa yerleşir (first-fit). Aynı yazar/yayınevi mümkün olduğunca
///   tek rafta kalır; grup asla ikiye bölünmez.
/// - **Taşan grup:** grubun yeri en büyük raf bütçesini aşıyorsa, rafa
///   sığan kadarı konur (kitap sırasıyla, sığmayan rafın kalanında
///   bekletilmez); ARTIK "Karışık kitaplar" rafına gider.
/// - **Akış modu (kitap adı / sayfa sayısı):** kitaplar tek sıraya dizilir
///   (BookSorter: eksik bilgi sonda), raflar fiziksel sırayla baştan
///   doldurulur; sıradaki kitap artık sığmıyorsa sıradaki rafa geçilir —
///   fiziksel kitaplık gibi (sıra bozulmaz). Sığmayanlar "Karışık
///   kitaplar" rafına gider.
/// - **Karışık raf:** artıklar için adı geçen gerçek raf varsa o raf
///   kullanılır (bütçesine saygılı; sığmayan küçük kitaplar atlanmaz,
///   sığan her kitap konur); yoksa plan sentetik bir "Karışık kitaplar"
///   rafı ekler.
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
    final thicknessAware = options.thicknessAware;

    final emptyShelves = [
      for (final shelf in ordered)
        PlannedShelf(
          shelf: shelf,
          books: const [],
          thicknessAware: thicknessAware,
        ),
    ];
    if (books.isEmpty) {
      return ShelfArrangement(shelves: emptyShelves);
    }
    if (ordered.isEmpty) {
      return ShelfArrangement(
        shelves: const [],
        warnings: [
          'Henüz raf tanımlanmamış. Önce raflarını ekleyip kapasitelerini gir.',
        ],
        unplaced: books,
      );
    }

    final warnings = <String>[];
    final buckets = List<List<BookModel>>.generate(ordered.length, (_) => []);

    // Yer bütçeleri yarım birim cinsinden: raf kapasitesi (kitap sayısı
    // kalibrasyonu) 1 kitap = 1 birim olacak şekilde bütçeye dönüşür.
    final remaining = [for (final shelf in ordered) shelf.capacity * 2];

    // Kitap havuzu: favori rafa yerleşenler çıkarılır.
    var pool = books;

    // 1) Favori yazarlar → favori raf (kullanıcı isteği: "favori rafıma
    //    favori yazarlarımı görebilsem"). Yalnız raf + yazarlar birlikte
    //    seçildiyse devrededir.
    if (options.hasFavorites) {
      final favIndex =
          ordered.indexWhere((shelf) => shelf.id == options.favoriteShelfId);
      if (favIndex >= 0) {
        final favorites =
            _favoriteOrderedBooks(books, options.favoriteAuthors);
        final placedFavorites = <BookModel>[];
        var notFit = 0;
        for (final book in favorites) {
          final cost = BookThickness.costHalfUnits(
            book.pageCount,
            thicknessAware: thicknessAware,
          );
          if (remaining[favIndex] >= cost) {
            buckets[favIndex].add(book);
            remaining[favIndex] -= cost;
            placedFavorites.add(book);
          } else {
            notFit++;
          }
        }
        if (notFit > 0) {
          warnings.add(
            'Favori yazarların $notFit kitabı favori rafa sığmadı; '
            'diğer raflara dağıtılıyor.',
          );
        }
        // Yalnız GERÇEKTEN yerleşen favori kitaplar havuzdan çıkarılır;
        // sığmayanlar kalan kitaplarla birlikte dağıtılır (kaybolmaz).
        final placedIds = {for (final book in placedFavorites) book.id};
        pool = books.where((book) => !placedIds.contains(book.id)).toList();
      }
    }

    final leftovers = <BookModel>[];

    if (criterion.isGrouped) {
      _placeByGroups(
        books: pool,
        criterion: criterion,
        ordered: ordered,
        remaining: remaining,
        thicknessAware: thicknessAware,
        buckets: buckets,
        leftovers: leftovers,
        warnings: warnings,
      );
    } else {
      _placeAsStream(
        books: pool,
        criterion: criterion,
        ordered: ordered,
        remaining: remaining,
        thicknessAware: thicknessAware,
        buckets: buckets,
        leftovers: leftovers,
        warnings: warnings,
      );
    }

    return _finalize(
      ordered: ordered,
      buckets: buckets,
      remaining: remaining,
      thicknessAware: thicknessAware,
      leftovers: leftovers,
      warnings: warnings,
    );
  }

  // ---------- Favori yazarlar ----------

  /// Favori yazarların kitaplarını yerleştirme sırasına dizer: yazarlar
  /// kullanıcının listediği sırayla; her yazarın kitapları ada göre
  /// (Türkçe alfabe, eşitlikte id). Bir kitap birden çok favori yazara
  /// uyuyorsa İLK yazara verilir (tekrar yok).
  static List<BookModel> _favoriteOrderedBooks(
    List<BookModel> books,
    List<String> favoriteAuthors,
  ) {
    final ordered = <BookModel>[];
    final seen = <String>{};
    for (final raw in favoriteAuthors) {
      final key = TextNormalizer.searchKey(raw.trim());
      if (key.isEmpty) continue;
      final forAuthor = <BookModel>[];
      for (final book in books) {
        if (seen.contains(book.id)) continue;
        final matches = book.authors.any(
          (author) => TextNormalizer.searchKey(author.trim()) == key,
        );
        if (matches) forAuthor.add(book);
      }
      forAuthor.sort((a, b) {
        final byTitle = TextNormalizer.compareTr(a.title, b.title);
        if (byTitle != 0) return byTitle;
        return a.id.compareTo(b.id);
      });
      ordered.addAll(forAuthor);
      for (final book in forAuthor) {
        seen.add(book.id);
      }
    }
    return ordered;
  }

  // ---------- Grup modu ----------

  static void _placeByGroups({
    required List<BookModel> books,
    required OrganizeCriterion criterion,
    required List<ShelfModel> ordered,
    required List<int> remaining,
    required bool thicknessAware,
    required List<List<BookModel>> buckets,
    required List<BookModel> leftovers,
    required List<String> warnings,
  }) {
    final groups = _groupsOf(books, criterion);
    final maxCapacity =
        ordered.map((shelf) => shelf.capacity).reduce(max);

    for (final group in groups) {
      final size = group.books.length;
      final weight = _weightOf(group.books, thicknessAware);
      final maxBudget = maxCapacity * 2;

      // Bütün grup, fiziksel sıraya göre ilk sığan rafa yerleşir.
      if (weight <= maxBudget) {
        final index = remaining.indexWhere((space) => space >= weight);
        if (index >= 0) {
          buckets[index].addAll(group.books);
          remaining[index] -= weight;
          continue;
        }
        // Raflarda toplam boşluk yetmiyor; grup bölünmez, Karışık'a.
        warnings.add(
          '"${group.display}" grubunun $size kitabı için raf alanı '
          'kalmadı; "${ShelfModel.mixShelfName}" rafına konuyor.',
        );
        leftovers.addAll(group.books);
        continue;
      }

      // Taşan grup: önce tamamen boş bir raf (sıra düzeninde ilk), o da
      // yoksa en çok boşluğu olan raf; sığan kadarı buraya (kitap sırası
      // korunur, sığmayan küçük kitap bekletilmez), artık Karışık'a
      // gider. Grup ikiye "bölünmez" — sığmayan kısmın yeri tek ve
      // bellidir.
      final index = _widestIndex(remaining, ordered);
      var taken = 0;
      final rest = <BookModel>[];
      for (final book in group.books) {
        final cost = BookThickness.costHalfUnits(
          book.pageCount,
          thicknessAware: thicknessAware,
        );
        if (remaining[index] >= cost) {
          buckets[index].add(book);
          remaining[index] -= cost;
          taken++;
        } else {
          rest.add(book);
        }
      }
      leftovers.addAll(rest);
      if (thicknessAware) {
        warnings.add(
          '${group.display} grubunun $size kitabı ${BookThickness.formatHalf(weight)} '
          'birim yer istiyor; en büyük raf kapasitesi $maxCapacity kitap '
          '(${BookThickness.formatHalf(maxCapacity * 2)} birim). Sığan '
          '$taken kitap ${ordered[index].name} rafına, kalan '
          '${size - taken} kitap "${ShelfModel.mixShelfName}" rafına '
          'konuyor.',
        );
      } else {
        warnings.add(
          '${group.display} grubunun $size kitabı en büyük raf '
          'kapasitesini ($maxCapacity) aşıyor: sığan $taken kitap '
          '${ordered[index].name} rafına, kalan ${size - taken} kitap '
          '"${ShelfModel.mixShelfName}" rafına konuyor.',
        );
      }
    }
  }

  /// Kitap listesinin toplam yeri (yarım birim).
  static int _weightOf(List<BookModel> books, bool thicknessAware) =>
      books.fold(
        0,
        (sum, book) => sum + BookThickness.costHalfUnits(
              book.pageCount,
              thicknessAware: thicknessAware,
            ),
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
    required bool thicknessAware,
    required List<List<BookModel>> buckets,
    required List<BookModel> leftovers,
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
        final cost = BookThickness.costHalfUnits(
          sorted[cursor].pageCount,
          thicknessAware: thicknessAware,
        );
        if (remaining[i] < cost) break;
        buckets[i].add(sorted[cursor]);
        remaining[i] -= cost;
        cursor++;
      }
    }
    if (cursor < sorted.length) {
      leftovers.addAll(sorted.getRange(cursor, sorted.length));
      warnings.add(
        'Toplam raf kapasitesi yetmedi: ${sorted.length - cursor} kitap '
        '"${ShelfModel.mixShelfName}" rafına konuyor.',
      );
    }
  }

  // ---------- Karışık rafı ve sonuç ----------

  static ShelfArrangement _finalize({
    required List<ShelfModel> ordered,
    required List<List<BookModel>> buckets,
    required List<int> remaining,
    required bool thicknessAware,
    required List<BookModel> leftovers,
    required List<String> warnings,
  }) {
    final planned = <PlannedShelf>[
      for (var i = 0; i < ordered.length; i++)
        PlannedShelf(
          shelf: ordered[i],
          books: buckets[i],
          thicknessAware: thicknessAware,
        ),
    ];

    if (leftovers.isEmpty) {
      return ShelfArrangement(
        shelves: planned,
        warnings: warnings,
      );
    }

    final mixKey = TextNormalizer.searchKey(ShelfModel.mixShelfName);
    final existingIndex = ordered
        .indexWhere((shelf) => TextNormalizer.searchKey(shelf.name) == mixKey);

    if (existingIndex >= 0) {
      // Kullanıcının gerçek "Karışık kitaplar" rafı: bütçesine saygılı
      // doldurulur; sığmayanlar plan dışı kalır ve açıkça bildirilir.
      var space = remaining[existingIndex];
      final placed = <BookModel>[];
      final rest = <BookModel>[];
      for (final book in leftovers) {
        final cost = BookThickness.costHalfUnits(
          book.pageCount,
          thicknessAware: thicknessAware,
        );
        if (space >= cost) {
          placed.add(book);
          space -= cost;
        } else {
          rest.add(book);
        }
      }
      if (placed.isNotEmpty) {
        planned[existingIndex] = PlannedShelf(
          shelf: ordered[existingIndex],
          books: [...buckets[existingIndex], ...placed],
          thicknessAware: thicknessAware,
        );
      }
      if (rest.isNotEmpty) {
        warnings.add(
          '${rest.length} kitap için "${ShelfModel.mixShelfName}" '
          'rafında da yer kalmadı; bu kitaplar plan dışı kaldı. '
          'Yeni raf ekleyip yeniden planla.',
        );
        return ShelfArrangement(
          shelves: planned,
          warnings: warnings,
          unplaced: rest,
        );
      }
      return ShelfArrangement(shelves: planned, warnings: warnings);
    }

    // Sentetik Karışık rafı: kapasitesi tam artıklara eşittir (kendisi
    // hiçbir zaman taşmaz). Kalınlık modunda kapasite, artıkların toplam
    // yerinin üst tam sayıya yuvarlanmışıdır.
    final totalWeight = _weightOf(leftovers, thicknessAware);
    final syntheticCapacity = thicknessAware
        ? (totalWeight + 1) ~/ 2
        : leftovers.length;
    planned.add(PlannedShelf(
      shelf: ShelfModel(
        id: 'plan-karisik-kitaplar',
        name: ShelfModel.mixShelfName,
        capacity: syntheticCapacity < 1 ? 1 : syntheticCapacity,
        location: '',
        order: ordered.length,
      ),
      books: leftovers,
      thicknessAware: thicknessAware,
    ));
    return ShelfArrangement(shelves: planned, warnings: warnings);
  }

  /// Taşan grup için hedef raf: tamamen boş raf (sıra düzeninde ilk) ya
  /// da en çok boşluğu olan raf. İkisi de yoksa ilk raf (kalan yer 0;
  /// tüm kitaplar Karışık'a gider).
  static int _widestIndex(List<int> remaining, List<ShelfModel> ordered) {
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i] == ordered[i].capacity * 2 && remaining[i] > 0) {
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

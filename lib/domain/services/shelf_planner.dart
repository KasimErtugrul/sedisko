import 'dart:math';

import 'package:equatable/equatable.dart';

import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';
import '../../data/models/shelf_model.dart';
import 'book_sort.dart';
import 'organize_criterion.dart';

/// Planlanan tek raf: raf tanımı + o rafa yerleştirilen kitaplar.
/// Kitap sırası, fiziksel diziliş sırasıdır (grup modunda yerleştirme
/// sırası, akış modunda alfabe/kalınlık sırası).
class PlannedShelf extends Equatable {
  const PlannedShelf({required this.shelf, required this.books});

  final ShelfModel shelf;
  final List<BookModel> books;

  int get count => books.length;

  @override
  List<Object?> get props => [shelf, books];
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
/// - **Grup modu (yazar / yayınevi):** gruplar kitap sayısı çoktan aza
///   sıralanır (eşitlikte Türkçe alfabe); her grup BÜTÜN halinde ilk
///   sığan rafa yerleşir (first-fit). Aynı yazar/yayınevi mümkün olduğunca
///   tek rafta kalır; grup asla ikiye bölünmez.
/// - **Taşan grup:** grubun boyutu en büyük raf kapasitesini aşıyorsa,
///   rafa sığan kadarı konur; ARTIK "Karışık kitaplar" rafına gider.
/// - **Akış modu (kitap adı / sayfa sayısı):** kitaplar tek sıraya dizilir
///   (BookSorter: eksik bilgi sonda), raflar fiziksel sırayla baştan
///   doldurulur; sığmayanlar "Karışık kitaplar" rafına gider.
/// - **Karışık raf:** artıklar için adı geçen gerçek raf varsa o raf
///   kullanılır (kapasitesine saygılı); yoksa plan sentetik bir
///   "Karışık kitaplar" rafı ekler.
/// - **Kararlılık:** aynı girdiden her zaman aynı plan çıkar (tüm
///   eşitlik kırıcıları: Türkçe alfabe → kitap adı → id).
abstract final class ShelfPlanner {
  static ShelfArrangement arrange(
    List<BookModel> books,
    List<ShelfModel> shelves,
    OrganizeCriterion criterion,
  ) {
    final ordered = [...shelves]..sort((a, b) => a.order.compareTo(b.order));

    final emptyShelves = [
      for (final shelf in ordered) PlannedShelf(shelf: shelf, books: const []),
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
    final remaining = [for (final shelf in ordered) shelf.capacity];
    final leftovers = <BookModel>[];

    if (criterion.isGrouped) {
      _placeByGroups(
        books: books,
        criterion: criterion,
        ordered: ordered,
        buckets: buckets,
        remaining: remaining,
        leftovers: leftovers,
        warnings: warnings,
      );
    } else {
      _placeAsStream(
        books: books,
        criterion: criterion,
        ordered: ordered,
        buckets: buckets,
        remaining: remaining,
        leftovers: leftovers,
        warnings: warnings,
      );
    }

    return _finalize(
      ordered: ordered,
      buckets: buckets,
      leftovers: leftovers,
      warnings: warnings,
    );
  }

  // ---------- Grup modu ----------

  static void _placeByGroups({
    required List<BookModel> books,
    required OrganizeCriterion criterion,
    required List<ShelfModel> ordered,
    required List<List<BookModel>> buckets,
    required List<int> remaining,
    required List<BookModel> leftovers,
    required List<String> warnings,
  }) {
    final groups = _groupsOf(books, criterion);
    final maxCapacity =
        ordered.map((shelf) => shelf.capacity).reduce(max);

    for (final group in groups) {
      final size = group.books.length;

      // Bütün grup, fiziksel sıraya göre ilk sığan rafa yerleşir.
      if (size <= maxCapacity) {
        final index =
            remaining.indexWhere((space) => space >= size);
        if (index >= 0) {
          buckets[index].addAll(group.books);
          remaining[index] -= size;
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
      // yoksa en çok boşluğu olan raf; sığan kadarı buraya, artık
      // Karışık'a gider. Grup ikiye "bölünmez" — sığmayan kısmın yeri
      // tek ve bellidir.
      final index = _widestIndex(remaining, ordered);
      final take = min(size, max(remaining[index], 0));
      if (take > 0) {
        buckets[index].addAll(group.books.take(take));
        remaining[index] -= take;
      }
      leftovers.addAll(group.books.skip(take));
      warnings.add(
        '${group.display} grubunun $size kitabı en büyük raf '
        'kapasitesini ($maxCapacity) aşıyor: sığan $take kitap '
        '${ordered[index].name} rafına, kalan ${size - take} kitap '
        '"${ShelfModel.mixShelfName}" rafına konuyor.',
      );
    }
  }

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
    required List<List<BookModel>> buckets,
    required List<int> remaining,
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

    var cursor = 0;
    for (var i = 0; i < ordered.length && cursor < sorted.length; i++) {
      final take = min(remaining[i], sorted.length - cursor);
      if (take > 0) {
        buckets[i].addAll(sorted.getRange(cursor, cursor + take));
        cursor += take;
        remaining[i] -= take;
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
    required List<BookModel> leftovers,
    required List<String> warnings,
  }) {
    final planned = <PlannedShelf>[
      for (var i = 0; i < ordered.length; i++)
        PlannedShelf(shelf: ordered[i], books: buckets[i]),
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
      // Kullanıcının gerçek "Karışık kitaplar" rafı: kapasitesine saygılı
      // doldurulur; sığmayanlar plan dışı kalır ve açıkça bildirilir.
      final space = ordered[existingIndex].capacity -
          buckets[existingIndex].length;
      final take = min(leftovers.length, max(space, 0));
      if (take > 0) {
        planned[existingIndex] = PlannedShelf(
          shelf: ordered[existingIndex],
          books: [...buckets[existingIndex], ...leftovers.take(take)],
        );
      }
      if (take < leftovers.length) {
        final rest = leftovers.skip(take).toList();
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
    // hiçbir zaman taşmaz).
    planned.add(PlannedShelf(
      shelf: ShelfModel(
        id: 'plan-karisik-kitaplar',
        name: ShelfModel.mixShelfName,
        capacity: leftovers.length,
        location: '',
        order: ordered.length,
      ),
      books: leftovers,
    ));
    return ShelfArrangement(shelves: planned, warnings: warnings);
  }

  /// Taşan grup için hedef raf: tamamen boş raf (sıra düzeninde ilk) ya
  /// da en çok boşluğu olan raf. İkisi de yoksa ilk raf (kalan yer 0;
  /// tüm kitaplar Karışık'a gider).
  static int _widestIndex(List<int> remaining, List<ShelfModel> ordered) {
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i] == ordered[i].capacity && remaining[i] > 0) return i;
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

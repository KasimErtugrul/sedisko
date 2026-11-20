// EŞDEĞERLİK + BAŞARIM testi (1.18.1): MovePlanBuilder yeniden yazıldı
// (raf-adı kuyrukları + yer-etiketi önbelleği). Bu dosya ESKİ
// uygulamayı referans olarak gömer ve her iki uygulamanın aynı
// girdiden BİREBİR AYNI planı ürettiğini doğrular; ayrıca büyük
// kitaplıkta sürenin makul sınıra indiğini ölçer.
//
// Referans gövde, 1.18.0'daki move_plan_builder.dart'ın birebir
// kopyasıdır (yalnız sınıf adı ReferenceMovePlanBuilder'dır).
import 'package:flutter_test/flutter_test.dart';

import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/domain/services/move_plan_builder.dart';
import 'package:kitaplik/domain/services/organize_criterion.dart';
import 'package:kitaplik/domain/services/organize_options.dart';
import 'package:kitaplik/domain/services/shelf_planner.dart';

// ---------- REFERANS (1.18.0) UYGULAMA ----------
// (book_model/shelf_model/shelf_planner importları üsttekinden ortaktır.)

import 'package:equatable/equatable.dart';

import 'package:kitaplik/core/utils/text_normalizer.dart';
import 'package:kitaplik/data/models/organize_plan_model.dart';

/// Taşıma planı sonucu: sıralı turlar + özet.
class RefMovePlanResult extends Equatable {
  const RefMovePlanResult({
    required this.turs,
    required this.movedCount,
    required this.untouchedCount,
  });

  final List<MoveTurModel> turs;

  /// Yer değiştirecek kitap sayısı.
  final int movedCount;

  /// Hedefi zaten doğru olan, kımıldamayacak kitap sayısı.
  final int untouchedCount;

  @override
  List<Object?> get props => [turs, movedCount, untouchedCount];
}

/// Hedef düzeni fiziksel bir yürüyüş planına çeviren saf servis.
///
/// Kullanıcının evdeki işi şudur: raflar arasında yürürken tek elde
/// [carryLimit] (varsayılan 10) kitap taşır ve her kitap için in çık
/// yapmak istemez. Bu yüzden plan şöyle kurulur:
///
/// - **Tur = tek yer (kat/oda).** Aynı yer etiketli rafların işleri tek
///   turda toplanır; yer değişimi yalnızca eldeki yığın başka yerde
///   konulacağı zaman olur.
/// - **Raf ziyareti sırası:** yerdeki raflar fiziksel sırayla (order)
///   gezilir; tanımsız raflar sonra, 'Rafsız' en sonda.
/// - **"Önce çıkanları al, sonra gelenleri koy":** bir rafta hem çıkış
///   hem giriş varsa ALMA emri KOYMA emrinden önce yazılır; yoksa rafa
///   koyacak yer açılamaz.
/// - **El sınırı:** raftan alınanlar eklendikten sonra eldeki toplam
///   [carryLimit]'i aşamaz. Sığmayanlar sonraki tura kalır (aynı yer için
///   "devam" turu açılır). Ziyaret anındaki anlık fazlalık, yığının rafta
///   yere bırakılıp yeniden toplanmasıyla çözülür — plan metni bunu
///   zaten emir emir anlatır.
/// - **Kararlılık:** tüm seçimler sayılabilir ve eşitlik kırıcıları
///   etiket alfabetik; aynı girdiden aynı plan çıkar.
abstract final class ReferenceMovePlanBuilder {
  static const int defaultCarryLimit = 10;

  /// Yer etiketi olmayan rafların ve 'Rafsız' kitapların ortak grubu.
  static const String noLocation = 'Yer belirtilmedi';

  static RefMovePlanResult build({
    required List<BookModel> books,
    required ShelfArrangement arrangement,
    required List<ShelfModel> shelves,
    int carryLimit = MovePlanBuilder.defaultCarryLimit,
  }) {
    assert(carryLimit >= 1, 'Taşıma sınırı en az 1 olmalı');

    // 1) Hareketler: hedefi olan ve hedefi mevcut raftan farklı kitaplar.
    final moves = <PlanMove>[];
    for (final book in books) {
      final target = arrangement.targetShelfOf(book.id);
      if (target == null) continue;
      final from = book.shelf.trim();
      final to = target.trim();
      if (from == to) continue;
      moves.add(PlanMove(
        bookId: book.id,
        title: book.title,
        fromShelf: from,
        toShelf: to,
      ));
    }
    if (moves.isEmpty) {
      return RefMovePlanResult(
        turs: const [],
        movedCount: 0,
        untouchedCount: books.length,
      );
    }

    // 2) Yer anahtarları: raf adı -> serbest etiket ('' olanlar da dahil).
    String locationOf(String shelfName) {
      if (shelfName.isEmpty) return noLocation;
      final key = TextNormalizer.searchKey(shelfName);
      for (final shelf in shelves) {
        if (TextNormalizer.searchKey(shelf.name) == key) {
          final location = shelf.location.trim();
          return location.isEmpty ? noLocation : location;
        }
      }
      return noLocation;
    }

    final pending = [...moves];
    final carried = <PlanMove>[];
    final turs = <MoveTurModel>[];

    // Aynı yerde geçen ardışık geçişler TEK turda birleşir: kullanıcı
    // aynı kattayken tur bölünmez; tur yalnızca yer değişince kapanır.
    var openLocation = '';
    var openLocationSet = false;
    var openActions = <MoveActionModel>[];

    void closeOpenTur() {
      if (!openLocationSet || openActions.isEmpty) {
        openLocationSet = false;
        openActions = <MoveActionModel>[];
        return;
      }
      turs.add(MoveTurModel(location: openLocation, actions: openActions));
      openLocationSet = false;
      openActions = <MoveActionModel>[];
    }

    // 3) Geçiş geçiş yürüyüş. Güvenlik sayacı: bozuk girdide sonsuz
    //    döngü koruması; normal planda geçiş sayısı buna hiç yaklaşmaz.
    var guard = 0;
    while ((pending.isNotEmpty || carried.isNotEmpty) &&
        guard++ < 4 * moves.length + 16) {
      final location = _nextLocation(pending, carried, locationOf);
      if (!openLocationSet || location != openLocation) closeOpenTur();
      openLocation = location;
      openLocationSet = true;
      final actions = openActions;

      for (final shelfName in _visitOrder(
        location: location,
        pending: pending,
        carried: carried,
        shelves: shelves,
        locationOf: locationOf,
      )) {
        final drops = [
          for (final move in carried)
            if (move.toShelf == shelfName) move,
        ];
        final outs = [
          for (final move in pending)
            if (move.fromShelf == shelfName) move,
        ];
        if (outs.isEmpty && drops.isEmpty) continue;

        // El sınırı: buradaki koymalar inince eldeki yer açılır; kalan
        // yer kadar kitap alınır.
        final space = carryLimit - (carried.length - drops.length);
        final take = space > 0 ? outs.take(space).toList() : <PlanMove>[];

        if (take.isNotEmpty) {
          actions.add(MoveActionModel(
            isPickup: true,
            shelf: shelfName,
            moves: take,
          ));
          for (final move in take) {
            pending.remove(move);
            carried.add(move);
          }
        }
        if (drops.isNotEmpty) {
          actions.add(MoveActionModel(
            isPickup: false,
            shelf: shelfName,
            moves: drops,
          ));
          for (final move in drops) {
            carried.remove(move);
          }
        }
      }

      if (openActions.isEmpty) {
        // Savunmacı: seçilen yerde iş yapılamadı (ör. el dolu ve buraya
        // bir şey konmuyor). Bekleyen ilk hareketi tek başına al.
        final first = pending.first;
        openActions.add(MoveActionModel(
          isPickup: true,
          shelf: first.fromShelf,
          moves: [first],
        ));
        pending.remove(first);
        carried.add(first);
      }
    }
    closeOpenTur();

    return RefMovePlanResult(
      turs: turs,
      movedCount: moves.length,
      untouchedCount: books.length - moves.length,
    );
  }

  // ---------- Yer seçimi ----------

  /// Sonraki turun yeri: el yığını doluysa yığının çoğunlukla gittiği
  /// yer; boşsa işi (alınacak + konacak) en fazla olan yer. Eşitlikte
  /// etiket alfabetik (kararlılık).
  static String _nextLocation(
    List<PlanMove> pending,
    List<PlanMove> carried,
    String Function(String) locationOf,
  ) {
    final counts = <String, int>{};
    if (carried.isNotEmpty) {
      for (final move in carried) {
        final location = locationOf(move.toShelf);
        counts[location] = (counts[location] ?? 0) + 1;
      }
    } else {
      for (final move in pending) {
        final from = locationOf(move.fromShelf);
        final to = locationOf(move.toShelf);
        counts[from] = (counts[from] ?? 0) + 1;
        counts[to] = (counts[to] ?? 0) + 1;
      }
    }

    String best = '';
    var bestCount = -1;
    for (final entry in counts.entries) {
      final count = entry.value;
      if (count > bestCount ||
          (count == bestCount && TextNormalizer.compareTr(
                entry.key,
                best,
              ) <
              0)) {
        best = entry.key;
        bestCount = count;
      }
    }
    return best;
  }

  /// Bu yerde ziyaret edilecek raflar, fiziksel gezinti sırasıyla:
  /// tanımlı raflar order'a göre, sonra tanımsız adlar alfabetik, en
  /// sonda 'Rafsız'.
  static List<String> _visitOrder({
    required String location,
    required List<PlanMove> pending,
    required List<PlanMove> carried,
    required List<ShelfModel> shelves,
    required String Function(String) locationOf,
  }) {
    final names = <String>{};
    for (final move in pending) {
      // Bu yerdeki kaynak raflar (alım) ve hedef raflar (konma) ziyaret
      // edilir; yalnızca kitap ALAN saf hedef raflar da listede olmalı,
      // aksi halde kitap bir geçiş elde bekler.
      if (locationOf(move.fromShelf) == location) names.add(move.fromShelf);
      if (locationOf(move.toShelf) == location) names.add(move.toShelf);
    }
    for (final move in carried) {
      // Elindeki yığının bu yerdeki hedefleri de ziyaret edilmelidir;
      // yoksa kitap geçiş sonunda elde kalır.
      if (locationOf(move.toShelf) == location) names.add(move.toShelf);
    }

    final orderedShelves = [...shelves]
      ..sort((a, b) => a.order.compareTo(b.order));

    int rank(String name) {
      if (name.isEmpty) return 2; // Rafsız en sonda
      final key = TextNormalizer.searchKey(name);
      final defined = orderedShelves
          .any((shelf) => TextNormalizer.searchKey(shelf.name) == key);
      return defined ? 0 : 1;
    }

    final result = names.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        if (rank(a) == 0) {
          final orderA = orderedShelves
              .firstWhere((shelf) =>
                  TextNormalizer.searchKey(shelf.name) ==
                  TextNormalizer.searchKey(a))
              .order;
          final orderB = orderedShelves
              .firstWhere((shelf) =>
                  TextNormalizer.searchKey(shelf.name) ==
                  TextNormalizer.searchKey(b))
              .order;
          return orderA.compareTo(orderB);
        }
        return TextNormalizer.compareTr(
          a.isEmpty ? ShelfModel.unassignedName : a,
          b.isEmpty ? ShelfModel.unassignedName : b,
        );
      });
    return result;
  }
}

// ---------- TESTLER ----------

BookModel kitap(String id, String title, List<String> authors, String shelf,
    {int pages = 300}) {
  return BookModel(
    id: id,
    title: title,
    authors: authors,
    shelf: shelf,
    pageCount: pages,
    addedAt: DateTime(2024, 1, 1),
  );
}

/// İki sonucu tur tur/emir emir karşılaştırır (Equatable zaten derin
/// eşitlik yapar; hata durumunda okunur çıktı için JSON'a bakarız).
String planJson(dynamic r) {
  return [
    'moved=${r.movedCount}',
    'untouched=${r.untouchedCount}',
    for (var i = 0; i < r.turs.length; i++) ...[
      'tur $i: ${r.turs[i].location}',
      for (var j = 0; j < r.turs[i].actions.length; j++)
        '  emir $j: ${r.turs[i].actions[j].isPickup ? "AL" : "KOY"} '
            '${r.turs[i].actions[j].shelf} (${r.turs[i].actions[j].moves.length}) '
            '[${r.turs[i].actions[j].moves.map((m) => m.bookId).join(",")}]',
    ],
  ].join('\n');
}

void expectSame(dynamic a, dynamic b, String scenario) {
  expect(planJson(a), planJson(b), reason: '$scenario: planlar farklı');
}

void main() {
  test('tek yer: elde 10 kitap sınırı ve devam turları', () {
    final shelves = [
      for (var i = 0; i < 3; i++)
        ShelfModel(id: 's$i', name: 'Raf ${i + 1}', lengthCm: 125, order: i),
    ];
    final books = <BookModel>[];
    for (var i = 0; i < 60; i++) {
      books.add(kitap('b$i', 'Kitap $i', ['Yazar ${i % 10}'],
          'Raf ${i % 2 + 1}'));
    }
    final arrangement = ShelfPlanner.arrange(
      books, shelves, OrganizeCriterion.author,
    );
    final planShelves = [for (final p in arrangement.shelves) p.shelf];
    final oldR = ReferenceMovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    final newR = MovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    expectSame(oldR, newR, 'tek yer');
    expect(oldR.movedCount, greaterThan(0));
  });

  test('çok yer (kat): turlar yer değiştirdikçe bölünür', () {
    final shelves = [
      const ShelfModel(
          id: 's0', name: 'Raf 1', lengthCm: 100, location: 'Alt kat', order: 0),
      const ShelfModel(
          id: 's1', name: 'Raf 2', lengthCm: 100, location: 'Alt kat', order: 1),
      const ShelfModel(
          id: 's2', name: 'Raf 3', lengthCm: 100, location: 'Üst kat', order: 2),
      const ShelfModel(
          id: 's3', name: 'Raf 4', lengthCm: 100, location: 'Üst kat', order: 3),
    ];
    final books = <BookModel>[];
    for (var i = 0; i < 80; i++) {
      books.add(kitap('b$i', 'Kitap $i', ['Yazar ${i % 16}'],
          'Raf ${i % 4 + 1}', pages: 150 + (i * 13) % 400));
    }
    final arrangement = ShelfPlanner.arrange(
      books, shelves, OrganizeCriterion.author,
    );
    final planShelves = [for (final p in arrangement.shelves) p.shelf];
    final oldR = ReferenceMovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    final newR = MovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    expectSame(oldR, newR, 'çok yer');
    expect(oldR.turs.length, greaterThanOrEqualTo(1));
  });

  test('rafsız kitaplar ve tanımsız hedef adları', () {
    final shelves = [
      const ShelfModel(
          id: 's0', name: 'Kitaplık', lengthCm: 75, location: '', order: 0),
      const ShelfModel(
          id: 's1', name: 'Balkon', lengthCm: 75, location: 'Balkon', order: 1),
    ];
    final books = <BookModel>[];
    for (var i = 0; i < 50; i++) {
      books.add(kitap('b$i', 'Kitap $i', ['Yazar ${i % 12}'],
          i % 3 == 0 ? '' : 'Kitaplık', pages: 200 + (i * 7) % 300));
    }
    final arrangement = ShelfPlanner.arrange(
      books, shelves, OrganizeCriterion.author,
    );
    final planShelves = [for (final p in arrangement.shelves) p.shelf];
    final oldR = ReferenceMovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    final newR = MovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    expectSame(oldR, newR, 'rafsız');
  });

  test('yer etiketinde büyük/küçük harf varyantları (eşitlik kırıcı)',
      () {
    final shelves = [
      const ShelfModel(
          id: 's0', name: 'Raf 1', lengthCm: 50, location: 'Salon', order: 0),
      const ShelfModel(
          id: 's1', name: 'Raf 2', lengthCm: 50, location: 'salon', order: 1),
      const ShelfModel(
          id: 's2', name: 'Raf 3', lengthCm: 50, location: 'Salon', order: 2),
    ];
    final books = <BookModel>[];
    for (var i = 0; i < 45; i++) {
      books.add(kitap('b$i', 'Kitap $i', ['Yazar ${i % 9}'],
          'Raf ${i % 3 + 1}'));
    }
    final arrangement = ShelfPlanner.arrange(
      books, shelves, OrganizeCriterion.title,
    );
    final planShelves = [for (final p in arrangement.shelves) p.shelf];
    final oldR = ReferenceMovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    final newR = MovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    expectSame(oldR, newR, 'harf varyantı');
  });

  test('aynı kitaba ait eşit görünen çift kayıt (bozuk veri)', () {
    final shelves = [
      const ShelfModel(
          id: 's0', name: 'Raf 1', lengthCm: 25, location: '', order: 0),
      const ShelfModel(
          id: 's1', name: 'Raf 2', lengthCm: 25, location: '', order: 1),
    ];
    final books = <BookModel>[
      kitap('x1', 'Aynı Kitap', ['Yazar'], 'Raf 1'),
      kitap('x1', 'Aynı Kitap', ['Yazar'], 'Raf 1'),
      kitap('x2', 'Öteki', ['Yazar 2'], ''),
      kitap('x3', 'Üçüncü', ['Yazar 3'], ''),
    ];
    final arrangement = ShelfPlanner.arrange(
      books, shelves, OrganizeCriterion.author,
    );
    final planShelves = [for (final p in arrangement.shelves) p.shelf];
    final oldR = ReferenceMovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    final newR = MovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    expectSame(oldR, newR, 'çift kayıt');
  });

  test('deterministik büyük karışık senaryo (120 hareket)', () {
    final shelves = [
      const ShelfModel(
          id: 's0', name: 'Raf 1', lengthCm: 62, location: 'Giriş', order: 0),
      const ShelfModel(
          id: 's1', name: 'Raf 2', lengthCm: 62, location: 'Giriş', order: 1),
      const ShelfModel(
          id: 's2', name: 'Raf 3', lengthCm: 62, location: 'Koridor', order: 2),
      const ShelfModel(
          id: 's3', name: 'Raf 4', lengthCm: 62, location: '', order: 3),
      const ShelfModel(
          id: 's4', name: 'Karışık kitaplar', lengthCm: 62, location: 'Koridor',
          order: 4),
    ];
    final books = <BookModel>[];
    for (var i = 0; i < 120; i++) {
      final shelf = i % 7 == 6 ? '' : 'Raf ${(i % 5) + 1}';
      books.add(kitap(
        'b$i',
        'Kitap $i',
        ['Yazar ${i % 22}'],
        shelf,
        pages: 120 + (i * 41) % 550,
      ));
    }
    final arrangement = ShelfPlanner.arrange(
      books, shelves, OrganizeCriterion.author,
      options: const OrganizeOptions(
        favoriteShelfId: 's0',
        favoriteAuthors: ['Yazar 3', 'Yazar 7'],
      ),
    );
    final planShelves = [for (final p in arrangement.shelves) p.shelf];
    final oldR = ReferenceMovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    final newR = MovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    expectSame(oldR, newR, 'karışık 120');
  });

  test('BAŞARIM: 3000 kitap planı artık saniyeler değil milisaniyeler',
      () {
    final shelfCount = 31;
    final shelves = [
      for (var i = 0; i < shelfCount; i++)
        ShelfModel(
            id: 's$i', name: 'Raf $i', lengthCm: 300, location: '',
            order: i),
    ];
    final books = [
      for (var i = 0; i < 3000; i++)
        kitap(
          'b$i',
          'Kitap $i',
          ['Yazar ${i % 600}'],
          'Raf ${i % shelfCount}',
          pages: 120 + (i * 31) % 600,
        ),
    ];
    final arrangement = ShelfPlanner.arrange(
      books, shelves, OrganizeCriterion.author,
    );
    final planShelves = [for (final p in arrangement.shelves) p.shelf];
    final sw = Stopwatch()..start();
    final result = MovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    sw.stop();
    // ignore: avoid_print
    print('3000 kitap plan süresi: ${sw.elapsedMilliseconds} ms, '
        'moved=${result.movedCount}');
    // ANR eşiği ~5 saniyedir; cömert bir üst sınır koyuyoruz (CI
    // yavaşlamalarına tolerans) ama eski 5 saniyelik blok artık
    // görünmemeli.
    expect(sw.elapsedMilliseconds, lessThan(2000));
    expect(result.movedCount, greaterThan(0));
    expect(result.turs, isNotEmpty);
  });

  test('taşınacak kitap yoksa boş sonuç', () {
    final shelves = [
      const ShelfModel(
          id: 's0', name: 'Raf 1', lengthCm: 25, location: '', order: 0),
    ];
    final books = [kitap('b1', 'Kitap', ['Yazar'], 'Raf 1')];
    final arrangement = ShelfPlanner.arrange(
      books, shelves, OrganizeCriterion.author,
    );
    final planShelves = [for (final p in arrangement.shelves) p.shelf];
    final newR = MovePlanBuilder.build(
        books: books, arrangement: arrangement, shelves: planShelves);
    expect(newR.movedCount, 0);
    expect(newR.turs, isEmpty);
    expect(newR.untouchedCount, 1);
  });
}

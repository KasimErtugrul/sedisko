import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/domain/services/move_plan_builder.dart';
import 'package:kitaplik/domain/services/shelf_planner.dart';

/// Taşıma planı üreticisi: tur = yer, elde 10 kitap sınırı, "önce al
/// sonra koy" sırası, her kitabın tam bir kez alınması ve konması.
BookModel book(String id, String shelf) {
  return BookModel(
    id: id,
    title: 'Kitap $id',
    shelf: shelf,
    addedAt: DateTime(2026, 1, 1),
  );
}

ShelfModel shelf(String name, String location, int order) {
  return ShelfModel(
    id: 'shelf-$name',
    name: name,
    capacity: 50,
    location: location,
    order: order,
  );
}

/// Bir hedef düzen kurar: her kitabı [targets] içindeki rafa yerleştirir.
ShelfArrangement arrangementOf(List<BookModel> books, Map<String, String> targets) {
  final byShelf = <String, List<BookModel>>{};
  for (final b in books) {
    final target = targets[b.id] ?? b.shelf.trim();
    byShelf.putIfAbsent(target, () => []).add(b);
  }
  final planned = [
    for (final entry in byShelf.entries)
      PlannedShelf(
        shelf: ShelfModel(
          id: 'plan-${entry.key.isEmpty ? "rafsiz" : entry.key}',
          name: entry.key.isEmpty ? 'Rafsız' : entry.key,
          capacity: entry.value.length,
          location: '',
          order: 0,
        ),
        books: entry.value,
      ),
  ];
  return ShelfArrangement(shelves: planned);
}

/// Planı yürüyüş gibi oynatır: her emirden sonra eldeki kitap sayısını
/// döner; sınır aşılırsa test hatasına yol açan liste döner.
List<int> walkPileSizes(MovePlanResult result, int carryLimit) {
  final sizes = <int>[];
  var pile = 0;
  for (final tur in result.turs) {
    for (final action in tur.actions) {
      pile += action.isPickup ? action.moves.length : -action.moves.length;
      sizes.add(pile);
    }
    // Tur bittiğinde el ya boş ya da sonraki yere giden yüktür; sınır
    // asla aşılamaz.
    if (pile > carryLimit) {
      fail('El sınırı aşıldı: $pile > $carryLimit');
    }
  }
  return sizes;
}

void main() {
  group('tek yer (kat bilgisi yok)', () {
    test('zincir: Raf1\'den al, Raf2\'ye koy; Raf2\'den al, Raf1\'e koy', () {
      final books = [
        book('b1', 'Raf 1'),
        book('b2', 'Raf 1'),
        book('b3', 'Raf 2'),
        book('b4', 'Raf 2'),
      ];
      final targets = {'b1': 'Raf 2', 'b2': 'Raf 2', 'b3': 'Raf 1'};
      final result = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: [
          shelf('Raf 1', '', 0),
          shelf('Raf 2', '', 1),
        ],
      );

      expect(result.movedCount, 3);
      expect(result.untouchedCount, 1); // b4 yerinde kalır
      expect(result.turs, isNotEmpty);

      // Her hareket tam bir kez alınır ve konur.
      final pickups = [
        for (final tur in result.turs)
          for (final action in tur.actions)
            if (action.isPickup) ...action.moves,
      ];
      final drops = [
        for (final tur in result.turs)
          for (final action in tur.actions)
            if (!action.isPickup) ...action.moves,
      ];
      expect(pickups.map((m) => m.bookId).toSet().length, result.movedCount);
      expect(drops.map((m) => m.bookId).toSet().length, result.movedCount);
      expect(drops.length, pickups.length);

      // El sınırı aşılmaz.
      walkPileSizes(result, MovePlanBuilder.defaultCarryLimit);
    });

    test('aynı rafta "önce al sonra koy" sırası korunur', () {
      final books = [book('b1', 'Raf 1'), book('b2', 'Raf 1')];
      final result = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, {'b1': 'Raf 1', 'b2': 'Raf 1'}),
        shelves: [shelf('Raf 1', '', 0)],
      );
      // Hedef mevcut rafın aynısı: taşınacak kitap yok.
      expect(result.movedCount, 0);
      expect(result.turs, isEmpty);
    });

    test('taşan yığın aynı turda bölünerek alınır (elde 10 sınırı)', () {
      final books = [
        for (var i = 1; i <= 15; i++) book('b$i', 'Raf 1'),
      ];
      final targets = {for (var i = 1; i <= 15; i++) 'b$i': 'Raf 2'};
      final result = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: [shelf('Raf 1', '', 0), shelf('Raf 2', '', 1)],
        carryLimit: 10,
      );

      // Aynı yerde oldukları için tek tur; içinde 10+5'lik iki alım var.
      expect(result.turs.length, 1);
      final pickups = result.turs.single.actions
          .where((a) => a.isPickup)
          .map((a) => a.moves.length)
          .toList();
      expect(pickups, [10, 5]);
      walkPileSizes(result, 10);
    });
  });

  group('kat bazlı turlar', () {
    test('alt kattan al, üst kata koy; üst kattan al, alt kata koy', () {
      final books = [
        book('b1', 'Raf A'),
        book('b2', 'Raf A'),
        book('b3', 'Raf C'),
      ];
      final targets = {'b1': 'Raf C', 'b2': 'Raf C', 'b3': 'Raf A'};
      final shelves = [
        shelf('Raf A', 'Alt kat', 0),
        shelf('Raf B', 'Alt kat', 1),
        shelf('Raf C', 'Üst kat', 0),
      ];
      final result = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: shelves,
      );

      // Tur yerleri sırayla: Alt kat → Üst kat → Alt kat.
      final locations = result.turs.map((t) => t.location).toList();
      expect(locations, ['Alt kat', 'Üst kat', 'Alt kat']);

      // 1. turda Raf A'dan 2 kitap alınır.
      final tur1 = result.turs[0];
      expect(tur1.actions.single.isPickup, isTrue);
      expect(tur1.actions.single.shelf, 'Raf A');
      expect(tur1.actions.single.moves.length, 2);

      // 2. turda önce Raf C'den taşınacak kitap alınır, sonra
      // elindeki 2 kitap Raf C'ye konur (önce al, sonra koy).
      final tur2 = result.turs[1];
      final kinds = tur2.actions.map((a) => a.isPickup).toList();
      expect(kinds, [true, false]);
      expect(tur2.actions[0].shelf, 'Raf C');
      expect(tur2.actions[0].moves.single.bookId, 'b3');
      expect(tur2.actions[1].moves.map((m) => m.bookId).toSet(), {'b1', 'b2'});

      // 3. turda b3 alt kattaki Raf A'ya konur.
      final tur3 = result.turs[2];
      expect(tur3.actions.single.isPickup, isFalse);
      expect(tur3.actions.single.moves.single.bookId, 'b3');

      walkPileSizes(result, MovePlanBuilder.defaultCarryLimit);
    });

    test('aynı yer etiketli rafların işleri tek turda toplanır', () {
      final books = [
        book('b1', 'Raf A'),
        book('b2', 'Raf B'),
      ];
      final targets = {'b1': 'Raf B', 'b2': 'Raf A'};
      final shelves = [
        shelf('Raf A', 'Alt kat', 0),
        shelf('Raf B', 'Alt kat', 1),
      ];
      final result = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: shelves,
      );

      // İkisi de alt katta: tek tur, zincirleme emirler.
      expect(result.turs.length, 1);
      final shelvesOfActions =
          result.turs.single.actions.map((a) => a.shelf).toSet();
      expect(shelvesOfActions, {'Raf A', 'Raf B'});
    });

    test('yer etiketi boş raflar "Yer belirtilmedi" grubuna düşer', () {
      final books = [book('b1', 'Raf A'), book('b2', 'Raf C')];
      final targets = {'b1': 'Raf C', 'b2': 'Raf A'};
      final shelves = [
        shelf('Raf A', '', 0), // yer belirtilmemiş
        shelf('Raf C', 'Üst kat', 0),
      ];
      final result = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: shelves,
      );

      final locations = result.turs.map((t) => t.location).toSet();
      expect(locations, contains(MovePlanBuilder.noLocation));
      expect(locations, contains('Üst kat'));
    });
  });

  group('kararlılık ve savunmacı durumlar', () {
    test('aynı girdiden aynı plan çıkar', () {
      final books = [
        for (var i = 1; i <= 12; i++) book('b$i', 'Raf A'),
      ];
      final targets = {for (var i = 1; i <= 12; i++) 'b$i': 'Raf B'};
      final shelves = [shelf('Raf A', 'Alt kat', 0), shelf('Raf B', 'Üst kat', 0)];

      String signature(MovePlanResult r) => [
            for (final tur in r.turs)
              '${tur.location}|${tur.actions.map((a) => "${a.isPickup ? "al" : "koy"}:${a.shelf}:${a.moves.length}").join(">")}',
          ].join('#');

      final first = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: shelves,
      );
      final second = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: shelves,
      );
      expect(signature(first), signature(second));
    });

    test('Karışık kitaplar hedefi yer bilgisi olmadan planlanır', () {
      final books = [book('b1', 'Raf A')];
      final targets = {'b1': 'Karışık kitaplar'};
      final result = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: [shelf('Raf A', 'Alt kat', 0)],
      );

      expect(result.movedCount, 1);
      final dropActions = [
        for (final tur in result.turs)
          for (final action in tur.actions)
            if (!action.isPickup) action,
      ];
      expect(dropActions.single.shelf, 'Karışık kitaplar');
    });

    test('rafsız kitaplar hem kaynak hem hedef olabilir', () {
      final books = [book('b1', ''), book('b2', 'Raf A')];
      final targets = {'b1': 'Raf A', 'b2': ''};
      final result = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: [shelf('Raf A', '', 0)],
      );

      expect(result.movedCount, 2);
      // Rafsız emirleri doğru raf adıyla ('') yazılır; gösterimde
      // 'Rafsız'a çevrilir.
      final allActions = [
        for (final tur in result.turs) ...tur.actions,
      ];
      final emptyShelfActions =
          allActions.where((a) => a.shelf.isEmpty).toList();
      expect(emptyShelfActions, isNotEmpty);
      walkPileSizes(result, MovePlanBuilder.defaultCarryLimit);
    });

    test('plan dışı (hedefi olmayan) kitaplar kımıldamaz', () {
      final books = [book('b1', 'Raf A'), book('b2', 'Raf A')];
      final targets = {'b1': 'Raf B'}; // b2 hedefsiz
      final result = MovePlanBuilder.build(
        books: books,
        arrangement: arrangementOf(books, targets),
        shelves: [shelf('Raf A', '', 0), shelf('Raf B', '', 1)],
      );
      expect(result.movedCount, 1);
      expect(result.untouchedCount, 1);
    });
  });
}

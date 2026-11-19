import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/domain/services/organize_criterion.dart';
import 'package:kitaplik/domain/services/shelf_planner.dart';

/// Hedef düzen planlayıcısı: çoktan aza gruplama, grup bütünlüğü,
/// taşan grubun Karışık'a aktarılması, akış modu ve kapasite uyarıları.
BookModel book(
  String id, {
  String title = '',
  List<String> authors = const [],
  String publisher = '',
  int pages = 0,
  String shelf = '',
}) {
  return BookModel(
    id: id,
    title: title.isEmpty ? 'Kitap $id' : title,
    authors: authors,
    publisher: publisher.isEmpty ? null : publisher,
    pageCount: pages,
    shelf: shelf,
    addedAt: DateTime(2026, 1, 1),
  );
}

ShelfModel shelf(String name, int capacity, {String location = '', int order = 0}) {
  return ShelfModel(
    id: 'shelf-$name',
    name: name,
    capacity: capacity,
    location: location,
    order: order,
  );
}

void main() {
  group('grup modu: yazara göre', () {
    test('yazarlar kitap sayısı çoktan aza dizilir', () {
      // Kullanıcı örneği: Ece Temelkuran'ın 5 kitabı, diğer yazarın 3'ü.
      final books = [
        for (var i = 1; i <= 5; i++)
          book('e$i', authors: ['Ece Temelkuran']),
        for (var i = 1; i <= 3; i++)
          book('a$i', authors: ['Ahmet Ümit']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('Raf 1', 50)],
        OrganizeCriterion.author,
      );

      final titles = arrangement.shelves.single.books
          .map((b) => b.authors.first)
          .toList();
      // İlk 5 kitap en çok kitaplı yazara ait.
      expect(titles.take(5), everyElement('Ece Temelkuran'));
      expect(titles.skip(5), everyElement('Ahmet Ümit'));
      expect(arrangement.warnings, isEmpty);
    });

    test('eşit sayıda gruplar Türkçe alfabeyle kırılır', () {
      final books = [
        book('1', authors: ['Cem']),
        book('2', authors: ['Çağlar']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('Raf 1', 10)],
        OrganizeCriterion.author,
      );
      expect(
        arrangement.shelves.single.books.map((b) => b.authors.first),
        ['Cem', 'Çağlar'], // c harfi ç'den önce
      );
    });

    test('grup bütünlüğü: sığmayan grup sonraki boş rafı alır', () {
      final books = [
        for (var i = 1; i <= 8; i++) book('g1-$i', authors: ['Yazar 1']),
        for (var i = 1; i <= 4; i++) book('g2-$i', authors: ['Yazar 2']),
        for (var i = 1; i <= 4; i++) book('g3-$i', authors: ['Yazar 3']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 10, order: 0), shelf('B', 10, order: 1)],
        OrganizeCriterion.author,
      );

      final a = arrangement.shelves[0];
      final b = arrangement.shelves[1];
      expect(a.books.map((b) => b.authors.first).toSet(), {'Yazar 1'});
      expect(b.books.map((b) => b.authors.first).toSet(), {'Yazar 2', 'Yazar 3'});
      expect(a.count, 8);
      expect(b.count, 8);
    });

    test('küçük sonraki grup önceki rafın boşluğuna geri döner (dolu raf)', () {
      final books = [
        for (var i = 1; i <= 6; i++) book('g1-$i', authors: ['Yazar 1']),
        for (var i = 1; i <= 5; i++) book('g2-$i', authors: ['Yazar 2']),
        for (var i = 1; i <= 4; i++) book('g3-$i', authors: ['Yazar 3']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 10, order: 0), shelf('B', 10, order: 1)],
        OrganizeCriterion.author,
      );

      final a = arrangement.shelves[0];
      final b = arrangement.shelves[1];
      // 6 → A (4 kaldı); 5 → A'ya sığmaz → B; 4 → A'nın boşluğuna geri.
      expect(a.books.map((b) => b.authors.first).toSet(),
          {'Yazar 1', 'Yazar 3'});
      expect(b.books.map((b) => b.authors.first).toSet(), {'Yazar 2'});
    });

    test('taşan grup: sığan kadarı rafda, artığı Karışık rafında', () {
      final books = [
        for (var i = 1; i <= 5; i++) book('e$i', authors: ['Ece Temelkuran']),
        for (var i = 1; i <= 3; i++) book('a$i', authors: ['Ahmet Ümit']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 4, order: 0), shelf('B', 4, order: 1)],
        OrganizeCriterion.author,
      );

      // Ece (5) > 4: raf A'ya 4 kitap, 1 kitap Karışık'a.
      final mix = arrangement.shelves
          .firstWhere((p) => p.shelf.name == ShelfModel.mixShelfName);
      expect(arrangement.shelves[0].count, 4);
      expect(mix.count, 1);
      expect(mix.books.single.authors.first, 'Ece Temelkuran');
      // Ahmet (3) raf B'ye bütün halinde.
      expect(arrangement.shelves[1].count, 3);
      // Uyarı metni taşan grubu anlatır.
      expect(arrangement.warnings.join(' '), contains('aşıyor'));
      // Hiçbir raf kapasitesini aşmıyor.
      for (final planned in arrangement.shelves) {
        expect(planned.count, lessThanOrEqualTo(planned.shelf.capacity));
      }
    });

    test('yazarsız kitaplar tek grupta toplanır', () {
      final books = [
        book('1'),
        book('2'),
        book('3', authors: ['Bir Yazar']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('Raf 1', 10)],
        OrganizeCriterion.author,
      );
      final names = arrangement.shelves.single.books
          .map((b) => b.authors.isEmpty ? 'Yazarsız' : b.authors.first)
          .toList();
      // Yazarsız 2 kitap çoktan aza sıralamada başa geçer.
      expect(names, ['Yazarsız', 'Yazarsız', 'Bir Yazar']);
    });
  });

  group('grup modu: yayınevine göre', () {
    test('aynı yayınevi kitapları birleşir, çoktan aza', () {
      final books = [
        book('1', publisher: 'İletişim'),
        book('2', publisher: 'İletişim'),
        book('3', publisher: 'Can Yayınları'),
        book('4'),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('Raf 1', 10)],
        OrganizeCriterion.publisher,
      );
      final publishers = arrangement.shelves.single.books
          .map((b) => b.publisher ?? 'Yayınevi bilinmiyor')
          .toList();
      // İletişim çoktan aza başta; tekli gruplar eşitlikte alfabe sırasıyla.
      expect(publishers,
          ['İletişim', 'İletişim', 'Can Yayınları', 'Yayınevi bilinmiyor']);
    });
  });

  group('akış modu', () {
    test('kitap adına göre A→Z dizilir, raf dolunca sıradakine geçer', () {
      final letters = 'ABCDEFGHIJKL'.split('');
      final books = [
        for (var i = 0; i < letters.length; i++)
          book('b$i', title: '${letters[i]} Kitabı'),
      ];
      final shelves = [
        shelf('Raf 1', 5, order: 0),
        shelf('Raf 2', 5, order: 1),
        shelf('Raf 3', 5, order: 2),
      ];
      final arrangement = ShelfPlanner.arrange(
        books, shelves, OrganizeCriterion.title,
      );

      expect(arrangement.shelves[0].books.map((b) => b.title),
          ['A Kitabı', 'B Kitabı', 'C Kitabı', 'D Kitabı', 'E Kitabı']);
      expect(arrangement.shelves[1].books.map((b) => b.title),
          ['F Kitabı', 'G Kitabı', 'H Kitabı', 'I Kitabı', 'J Kitabı']);
      expect(arrangement.shelves[2].books.map((b) => b.title),
          ['K Kitabı', 'L Kitabı']);
      expect(arrangement.warnings, isEmpty);
    });

    test('sayfa sayısına göre inceden kalına; bilinmeyenler sonda', () {
      final books = [
        book('b1', pages: 0),
        book('b2', pages: 300),
        book('b3', pages: 120),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('Raf 1', 10)],
        OrganizeCriterion.pageCount,
      );
      expect(
        arrangement.shelves.single.books.map((b) => b.id),
        ['b3', 'b2', 'b1'],
      );
    });

    test('toplam kapasite yetmezse artıklar Karışık rafına gider', () {
      final books = [
        for (var i = 1; i <= 12; i++) book('b$i'),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('Raf 1', 5)],
        OrganizeCriterion.title,
      );
      final mix = arrangement.shelves
          .firstWhere((p) => p.shelf.name == ShelfModel.mixShelfName);
      expect(mix.count, 7);
      expect(arrangement.shelves[0].count, 5);
      expect(arrangement.warnings.join(' '), contains('yetmedi'));
    });
  });

  group('Karışık kitaplar rafı', () {
    test('kullanıcının gerçek Karışık rafı varsa o kullanılır', () {
      final books = [for (var i = 1; i <= 12; i++) book('b$i')];
      final arrangement = ShelfPlanner.arrange(
        books,
        [
          shelf('Raf 1', 5, order: 0),
          shelf('Karışık kitaplar', 10, order: 1),
        ],
        OrganizeCriterion.title,
      );

      final mixIndex = arrangement.shelves
          .indexWhere((p) => p.shelf.name == 'Karışık kitaplar');
      expect(mixIndex, 1);
      expect(arrangement.shelves[1].count, 7); // kalan 7 kitap
      // Sentetik raf EKLENMEMİŞ.
      expect(arrangement.shelves.length, 2);
    });

    test('Karışık rafı da dolarsa gerisi plan dışı kalır ve uyarılır', () {
      final books = [for (var i = 1; i <= 12; i++) book('b$i')];
      final arrangement = ShelfPlanner.arrange(
        books,
        [
          shelf('Raf 1', 5, order: 0),
          shelf('Karışık kitaplar', 3, order: 1),
        ],
        OrganizeCriterion.title,
      );
      expect(arrangement.shelves[1].count, 3);
      expect(arrangement.unplaced.length, 4);
      expect(arrangement.warnings.join(' '), contains('plan dışı'));
    });
  });

  group('savunmacı durumlar', () {
    test('kitaplık boşsa uyarı yok, raflar boş planlanır', () {
      final arrangement = ShelfPlanner.arrange(
        const [],
        [shelf('Raf 1', 10)],
        OrganizeCriterion.author,
      );
      expect(arrangement.shelves.single.count, 0);
      expect(arrangement.warnings, isEmpty);
    });

    test('raf tanımı yoksa tüm kitaplar plansız kalır', () {
      final books = [book('b1'), book('b2')];
      final arrangement = ShelfPlanner.arrange(
        books, const [], OrganizeCriterion.author,
      );
      expect(arrangement.shelves, isEmpty);
      expect(arrangement.unplaced.length, 2);
      expect(arrangement.warnings, isNotEmpty);
    });

    test('aynı girdiden aynı plan çıkar (kararlılık)', () {
      final books = [
        for (var i = 1; i <= 7; i++) book('e$i', authors: ['Ece Temelkuran']),
        for (var i = 1; i <= 4; i++) book('a$i', authors: ['Ahmet Ümit']),
        for (var i = 1; i <= 2; i++) book('k$i', authors: ['Kemal']),
      ];
      final shelves = [
        shelf('B', 6, order: 1),
        shelf('A', 6, order: 0), // tanım sırası karışık ama order net
      ];
      final first = ShelfPlanner.arrange(books, shelves, OrganizeCriterion.author);
      final second =
          ShelfPlanner.arrange(books, shelves, OrganizeCriterion.author);

      List<String> signature(ShelfArrangement a) => [
        for (final planned in a.shelves)
          '${planned.shelf.name}:${planned.books.map((b) => b.id).join(",")}',
      ];
      expect(signature(first), signature(second));
      // order'a göre Raf A önce gelir.
      expect(first.shelves.first.shelf.name, 'A');
    });
  });
}

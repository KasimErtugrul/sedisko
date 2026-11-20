import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/domain/services/organize_criterion.dart';
import 'package:kitaplik/domain/services/organize_options.dart';
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

ShelfModel shelf(String name, int bookCapacity,
    {String location = '', int order = 0}) {
  // Eski kitap-sayısı kalibrasyonu korunur: N normal kitap ≈ N × 2,5 cm
  // (BookThickness ölçeği; bilinmeyen sayfalı kitap 2,5 cm yer kaplar).
  // Böylece test senaryoları 1.19.0 öncesi davranışla aynı kalır.
  return ShelfModel(
    id: 'shelf-$name',
    name: name,
    lengthCm: (bookCapacity * ShelfModel.legacyBookCm).ceil(),
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

    test('taşan yazar grubu bölünmez: bütün halinde Karışık rafına gider', () {
      final books = [
        for (var i = 1; i <= 5; i++) book('e$i', authors: ['Ece Temelkuran']),
        for (var i = 1; i <= 3; i++) book('a$i', authors: ['Ahmet Ümit']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 4, order: 0), shelf('B', 4, order: 1)],
        OrganizeCriterion.author,
      );

      // Ece (5) > 4: yazar BÖLÜNMEZ — 5 kitabın tamamı Karışık'a gider,
      // raf boş kalması kabul edilir (kullanıcı kuralı, 1.17.0).
      final mix = arrangement.shelves
          .firstWhere((p) => p.shelf.name == ShelfModel.mixShelfName);
      expect(arrangement.shelves[0].books.map((b) => b.authors.first),
          everyElement('Ahmet Ümit'));
      expect(arrangement.shelves[0].count, 3);
      expect(arrangement.shelves[1].count, 0);
      expect(mix.count, 5);
      expect(mix.books.map((b) => b.authors.first),
          everyElement('Ece Temelkuran'));
      // Uyarı metni bölünmeme kuralını anlatır.
      expect(arrangement.warnings.join(' '), contains('bölünmedi'));
      // Hiçbir raf cm bütçesini aşmıyor.
      for (final planned in arrangement.shelves) {
        expect(planned.usedMm, lessThanOrEqualTo(planned.capacityMm));
      }
    });

    test('değişmez: yazara göre düzende hiçbir yazar iki rafta yer almaz', () {
      final sizes = [12, 9, 7, 5, 3, 2, 1];
      final books = [
        for (var i = 0; i < sizes.length; i++)
          for (var j = 1; j <= sizes[i]; j++)
            book('g$i-$j', authors: ['Yazar $i']),
        for (var j = 1; j <= 4; j++) book('s$j'), // yazarsız
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [
          shelf('A', 10, order: 0),
          shelf('B', 15, order: 1),
          shelf('C', 20, order: 2),
        ],
        OrganizeCriterion.author,
      );

      // Her yazarın kitapları tam olarak BİR rafta toplanır.
      for (var i = 0; i < sizes.length; i++) {
        final shelvesOfAuthor = arrangement.shelves
            .where((p) => p.books.any((b) =>
                b.authors.isNotEmpty && b.authors.first == 'Yazar $i'))
            .toList();
        expect(shelvesOfAuthor.length, 1, reason: 'Yazar $i bölündü');
        expect(
          shelvesOfAuthor.single.books
              .where((b) =>
                  b.authors.isNotEmpty && b.authors.first == 'Yazar $i')
              .length,
          sizes[i],
        );
      }
      // Hiçbir raf cm bütçesini aşmaz; bütün kitaplar planlıdır.
      for (final planned in arrangement.shelves) {
        expect(planned.usedMm, lessThanOrEqualTo(planned.capacityMm));
      }
      expect(arrangement.unplaced, isEmpty);
      expect(arrangement.totalPlannedCount, books.length);
    });

    test('yayınevi kriterinde taşan grup bölünebilir (kural yalnız yazarlar için)', () {
      final books = [
        for (var i = 1; i <= 5; i++) book('p$i', publisher: 'Can Yayınları'),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 4, order: 0), shelf('B', 4, order: 1)],
        OrganizeCriterion.publisher,
      );

      // Yayınevi grubu 5 > 4: 1.13.0'dan beri davranış sürer — 4 kitap
      // raf A'ya, 1 kitap Karışık'a (kullanıcı kuralı yalnız yazarlar
      // için istendi).
      expect(arrangement.shelves[0].count, 4);
      final mix = arrangement.shelves
          .firstWhere((p) => p.shelf.name == ShelfModel.mixShelfName);
      expect(mix.count, 1);
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

  group('cm kalınlık modeli (1.19.0: 420 sayfa ≈ 3 cm, 130 sayfa ≈ 1 cm)', () {
    test('kalın yazar grubu cm bütçesine sığmazsa bölünmez, Karışık rafına gider',
        () {
      // 700 sayfa = 49 mm (BookThickness.mmOf). Raf 4 kitap kalibrasyonu
      // → 10 cm = 100 mm. Kalın Yazar'ın 3 kitabı 147 mm eder: bütçeyi
      // aşıyor → yazar bölünmez, tamamı Karışık'a.
      final books = [
        for (var i = 1; i <= 3; i++)
          book('k$i', authors: ['Kalın Yazar'], pages: 700),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 4)],
        OrganizeCriterion.author,
      );

      expect(arrangement.shelves[0].count, 0);
      final mix = arrangement.shelves
          .firstWhere((p) => p.shelf.name == ShelfModel.mixShelfName);
      expect(mix.count, 3);
      expect(arrangement.warnings.join(' '), contains('bölünmedi'));
    });

    test('cm bütçesi grup yerleştirmeyi belirler', () {
      // Kalın Yazar: 3 kitap × 700 sayfa = 147 mm; İnce Yazar: 2 kitap
      // × 100 sayfa = 16 mm; Orta Yazar: 2 kitap × 525 sayfa = 74 mm.
      // Raf A ve B 6 kitap kalibrasyonu (15 cm = 150 mm). Kalın → A'yı
      // doldurur; İnce (16 mm) A'ya sığmaz → B; Orta (74 mm) → B.
      // Kitap SAYISI olarak A'ya İnce+Orta sığardı ama cm sığmaz.
      final books = [
        for (var i = 1; i <= 3; i++)
          book('k$i', authors: ['Kalın Yazar'], pages: 700),
        for (var i = 1; i <= 2; i++)
          book('i$i', authors: ['İnce Yazar'], pages: 100),
        for (var i = 1; i <= 2; i++)
          book('o$i', authors: ['Orta Yazar'], pages: 525),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 6, order: 0), shelf('B', 6, order: 1)],
        OrganizeCriterion.author,
      );

      expect(arrangement.shelves[0].books.map((b) => b.id),
          ['k1', 'k2', 'k3']);
      expect(arrangement.shelves[1].books.map((b) => b.id),
          ['i1', 'i2', 'o1', 'o2']);
      // Hiçbir raf cm bütçesini aşmaz; hiçbir yazar bölünmedi.
      for (final planned in arrangement.shelves) {
        expect(planned.usedMm, lessThanOrEqualTo(planned.capacityMm));
      }
      expect(arrangement.warnings, isEmpty);
    });

    test('cm modelinde de yazar bölünmez', () {
      final books = [
        for (var i = 1; i <= 5; i++) book('k$i', authors: ['Yazar'], pages: 700),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 4)],
        OrganizeCriterion.author,
      );

      // 5 kitaplık yazar 4'lük rafa sığmaz: bölünmez, tamamı Karışık'a.
      expect(arrangement.shelves[0].count, 0);
      final mix = arrangement.shelves
          .firstWhere((p) => p.shelf.name == ShelfModel.mixShelfName);
      expect(mix.count, 5);
    });

    test('akış modunda sıradaki kitap sığmazsa sıradaki rafa geçilir', () {
      // b1 1000 sayfa (70 mm), b2 525 (37 mm), b3 100 (8 mm).
      // Raf A bütçesi 10 cm (100 mm): b1 sığar (30 mm kalır), b2 (37 mm)
      // sığmaz → sıra BOZULMAZ, b2 raf B'den başlar.
      final books = [
        book('b1', title: 'A Kitabı', pages: 1000),
        book('b2', title: 'B Kitabı', pages: 525),
        book('b3', title: 'C Kitabı', pages: 100),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 4, order: 0), shelf('B', 4, order: 1)],
        OrganizeCriterion.title,
      );

      expect(arrangement.shelves[0].books.map((b) => b.id), ['b1']);
      expect(arrangement.shelves[1].books.map((b) => b.id), ['b2', 'b3']);
    });

    test('bilinmeyen sayfalı kitaplar 2,5 cm sayılır', () {
      final books = [for (var i = 1; i <= 5; i++) book('b$i')];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 4)],
        OrganizeCriterion.title,
      );
      expect(arrangement.shelves[0].count, 4);
      final mix = arrangement.shelves
          .firstWhere((p) => p.shelf.name == ShelfModel.mixShelfName);
      expect(mix.count, 1);
    });

    test('karışık kitaplar rafı cm bütçesine saygılıdır', () {
      // Kalın 3 kitap (3 × 49 mm = 147 mm), gerçek Karışık rafı 4 kitap
      // kalibrasyonu (10 cm = 100 mm): 2 tanesi sığar, 1'i plan dışı kalır.
      final books = [
        for (var i = 1; i <= 3; i++) book('b$i', pages: 700),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('Karışık kitaplar', 4)],
        OrganizeCriterion.title,
      );
      expect(arrangement.shelves.single.count, 2);
      expect(arrangement.unplaced.length, 1);
    });
  });

  group('favori raf ve favori yazarlar (1.15.0)', () {
    test('favori yazarların kitapları favori rafa konur', () {
      final books = [
        book('e1', authors: ['Ece Temelkuran']),
        book('e2', authors: ['Ece Temelkuran']),
        for (var i = 1; i <= 3; i++) book('a$i', authors: ['Ahmet Ümit']),
      ];
      // Raf A kapasitesi 4 kitap (8 yarım birim): e1+e2 = 4 yarım birim
      // yer kaplar, kalan 4 yarım birim Ahmet grubuna (6 yarım birim)
      // yetmez → Ahmet raf B'ye gider. Favori rafın başında favori
      // yazarın kitapları durur.
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 4, order: 0), shelf('B', 10, order: 1)],
        OrganizeCriterion.author,
        options: const OrganizeOptions(
          favoriteShelfId: 'shelf-A',
          favoriteAuthors: ['Ece Temelkuran'],
        ),
      );

      expect(arrangement.shelves[0].books.map((b) => b.id), ['e1', 'e2']);
      expect(arrangement.shelves[1].books.map((b) => b.id),
          ['a1', 'a2', 'a3']);
      // Favori raf 4'lük yerinin 2'sini kullanır; kalan boşluk favori
      // yazarlara ayrılır (uyarıyla bildirilir) ve bölünme olmaz.
      expect(arrangement.warnings.join(' '),
          contains('yalnızca favori yazarların'));
      expect(arrangement.warnings.join(' '), isNot(contains('bölünmedi')));
    });

    test('favori yazarlar kullanıcının listediği sırayla yerleşir', () {
      final books = [
        book('e1', authors: ['Ece Temelkuran']),
        book('a1', authors: ['Ahmet Ümit']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 10)],
        OrganizeCriterion.author,
        options: const OrganizeOptions(
          favoriteShelfId: 'shelf-A',
          // Alfabe tersi liste: Ahmet önceliklidir.
          favoriteAuthors: ['Ahmet Ümit', 'Ece Temelkuran'],
        ),
      );
      expect(arrangement.shelves[0].books.map((b) => b.id), ['a1', 'e1']);
    });

    test('kullanıcı örneği: 35lik favori raf sığmazsa 30da kalır, yazar bölünmez', () {
      final books = [
        for (var i = 1; i <= 20; i++) book('a$i', authors: ['Yazar A']),
        for (var i = 1; i <= 10; i++) book('b$i', authors: ['Yazar B']),
        for (var i = 1; i <= 8; i++) book('c$i', authors: ['Yazar C']),
        for (var i = 1; i <= 5; i++) book('d$i', authors: ['Yazar D']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('Favori', 35, order: 0), shelf('Raf 2', 50, order: 1)],
        OrganizeCriterion.author,
        options: const OrganizeOptions(
          favoriteShelfId: 'shelf-Favori',
          favoriteAuthors: ['Yazar A', 'Yazar B', 'Yazar C'],
        ),
      );

      final favorite = arrangement.shelves[0];
      final other = arrangement.shelves[1];
      // Favori raf: 35 yerine 30 kitap — Yazar C'nin 8'lik grubu
      // sığmadığı için bölünmedi, raf eksik doldu ("az olsun").
      expect(favorite.count, 30);
      expect(favorite.books.map((b) => b.authors.first).toSet(),
          {'Yazar A', 'Yazar B'});
      // Yazar C'nin 8 kitabının TAMAMI Raf 2'de; başka rafta yok.
      final cElsewhere = arrangement.shelves
          .where((p) => p.shelf.name != 'Raf 2')
          .expand((p) => p.books)
          .where((b) => b.authors.first == 'Yazar C');
      expect(cElsewhere, isEmpty);
      expect(
        other.books.where((b) => b.authors.first == 'Yazar C').length,
        8,
      );
      // Favori olmayan Yazar D favori rafa alınmadı.
      expect(favorite.books.map((b) => b.authors.first),
          isNot(contains('Yazar D')));
      expect(arrangement.warnings.join(' '), contains('bölünmedi'));
    });

    test('favori rafa bütün olarak sığmayan favori yazar bölünmez', () {
      final books = [
        for (var i = 1; i <= 3; i++) book('e$i', authors: ['Ece Temelkuran']),
        for (var i = 1; i <= 2; i++) book('a$i', authors: ['Ahmet Ümit']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 2, order: 0), shelf('B', 10, order: 1)],
        OrganizeCriterion.author,
        options: const OrganizeOptions(
          favoriteShelfId: 'shelf-A',
          favoriteAuthors: ['Ece Temelkuran'],
        ),
      );

      // Ece'nin 3 kitabı 2'lik favori rafa BÜTÜN olarak sığmaz:
      // bölünmez, tamamı raf B'ye gider. Favori raf boş kalır ve
      // yalnızca favori yazarlara ayrıldığından Ahmet oraya alınmaz.
      expect(arrangement.shelves[0].count, 0);
      expect(arrangement.shelves[1].books.map((b) => b.id),
          ['e1', 'e2', 'e3', 'a1', 'a2']);
      expect(arrangement.warnings.join(' '), contains('bölünmedi'));
    });

    test('hiçbir rafa sığmayan favori yazar bütün halinde Karışık rafına gider', () {
      final books = [
        for (var i = 1; i <= 6; i++) book('e$i', authors: ['Ece Temelkuran']),
        book('a1', authors: ['Ahmet Ümit']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('Fav', 2, order: 0), shelf('B', 2, order: 1)],
        OrganizeCriterion.author,
        options: const OrganizeOptions(
          favoriteShelfId: 'shelf-Fav',
          favoriteAuthors: ['Ece Temelkuran'],
        ),
      );

      // Ece (6 kitap) favori rafa da, raf B'ye de sığmıyor: bölünmez,
      // tamamı Karışık rafına konuyor.
      final mix = arrangement.shelves
          .firstWhere((p) => p.shelf.name == ShelfModel.mixShelfName);
      expect(arrangement.shelves[0].count, 0);
      expect(arrangement.shelves[1].count, 1); // Ahmet
      expect(mix.count, 6);
      expect(
        mix.books.every((b) => b.authors.first == 'Ece Temelkuran'),
        isTrue,
      );
      expect(arrangement.warnings.join(' '), contains('hiçbir rafta'));
    });

    test('gerçek Karışık rafı bütün yazar grubuna yetmezse grup yerinde bırakılır', () {
      final books = [
        for (var i = 1; i <= 8; i++) book('x$i', authors: ['Büyük Yazar']),
        for (var i = 1; i <= 2; i++) book('y$i', authors: ['Küçük Yazar']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [
          shelf('A', 4, order: 0),
          shelf('Karışık kitaplar', 3, order: 1),
        ],
        OrganizeCriterion.author,
      );

      // Büyük Yazar (8) tek rafın kapasitesini (4) aşıyor: bölünmez,
      // Karışık rafı (3) de yetmez → 8 kitap mevcut yerinde bırakılır
      // ve plan dışı bildirilir; Küçük Yazar raf A'ya bütün gider.
      final mixIndex = arrangement.shelves
          .indexWhere((p) => p.shelf.name == 'Karışık kitaplar');
      expect(arrangement.shelves[0].books.map((b) => b.authors.first).toSet(),
          {'Küçük Yazar'});
      expect(arrangement.shelves[mixIndex].count, 0);
      expect(arrangement.unplaced.length, 8);
      expect(
        arrangement.unplaced
            .every((b) => b.authors.first == 'Büyük Yazar'),
        isTrue,
      );
      expect(arrangement.warnings.join(' '),
          contains('mevcut yerlerinde bırakıldı'));
    });

    test('yarım tercih (yalnız raf) planı etkilemez', () {
      final books = [
        book('e1', authors: ['Ece Temelkuran']),
        book('a1', authors: ['Ahmet Ümit']),
      ];
      final withoutFavorites = ShelfPlanner.arrange(
        books, [shelf('A', 10)], OrganizeCriterion.author,
      );
      final halfPreference = ShelfPlanner.arrange(
        books,
        [shelf('A', 10)],
        OrganizeCriterion.author,
        options: const OrganizeOptions(favoriteShelfId: 'shelf-A'),
      );

      String signature(ShelfArrangement a) => [
            for (final planned in a.shelves)
              '${planned.shelf.name}:${planned.books.map((b) => b.id).join(",")}',
          ].join('|');
      expect(signature(halfPreference), signature(withoutFavorites));
    });

    test('kitaplıkta olmayan favori yazar sorun yaratmaz', () {
      final books = [
        book('a1', authors: ['Ahmet Ümit']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 10, order: 0), shelf('B', 10, order: 1)],
        OrganizeCriterion.author,
        options: const OrganizeOptions(
          favoriteShelfId: 'shelf-A',
          favoriteAuthors: ['Var Olmayan Yazar'],
        ),
      );
      // Favori raf rezerve kalır (yazar kitaplıkta yok bile olsa);
      // Ahmet raf B'ye bütün halinde gider.
      expect(arrangement.shelves[0].count, 0);
      expect(arrangement.shelves[1].books.map((b) => b.id), ['a1']);
      expect(arrangement.warnings.join(' '),
          contains('yalnızca favori yazarların'));
    });

    test('bilinmeyen favori raf kimliği yok sayılır', () {
      final books = [
        book('e1', authors: ['Ece Temelkuran']),
        book('a1', authors: ['Ahmet Ümit']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 10)],
        OrganizeCriterion.author,
        options: const OrganizeOptions(
          favoriteShelfId: 'shelf-yok',
          favoriteAuthors: ['Ece Temelkuran'],
        ),
      );
      // Normal kriter planı: grup eşit, alfabe Ahmet'i önce koyar.
      expect(arrangement.shelves[0].books.map((b) => b.id), ['a1', 'e1']);
    });

    test('çok yazarlı kitap favori yazara uyar', () {
      final books = [
        book('m1', authors: ['Ayşe Kulin', 'Ece Temelkuran']),
        book('a1', authors: ['Ahmet Ümit']),
      ];
      final arrangement = ShelfPlanner.arrange(
        books,
        [shelf('A', 10, order: 0), shelf('B', 10, order: 1)],
        OrganizeCriterion.author,
        options: const OrganizeOptions(
          favoriteShelfId: 'shelf-A',
          favoriteAuthors: ['Ece Temelkuran'],
        ),
      );
      // m1 favori yazar Ece'ye uyar ve favori rafa konur; favori raf
      // yalnızca favori yazarlara ayrıldığından Ahmet raf B'ye gider.
      expect(arrangement.shelves[0].books.map((b) => b.id), ['m1']);
      expect(arrangement.shelves[1].books.map((b) => b.id), ['a1']);
    });

    test('favorilerle plan kararlıdır', () {
      final books = [
        for (var i = 1; i <= 3; i++) book('e$i', authors: ['Ece Temelkuran']),
        for (var i = 1; i <= 2; i++) book('a$i', authors: ['Ahmet Ümit']),
      ];
      final shelves = [shelf('B', 5, order: 1), shelf('A', 3, order: 0)];
      final options = const OrganizeOptions(
        favoriteShelfId: 'shelf-A',
        favoriteAuthors: ['Ece Temelkuran'],
      );
      final first = ShelfPlanner.arrange(
        books, shelves, OrganizeCriterion.author, options: options,
      );
      final second = ShelfPlanner.arrange(
        books, shelves, OrganizeCriterion.author, options: options,
      );

      String signature(ShelfArrangement a) => [
            for (final planned in a.shelves)
              '${planned.shelf.name}:${planned.books.map((b) => b.id).join(",")}',
          ].join('|');
      expect(signature(first), signature(second));
      expect(first.shelves.first.shelf.name, 'A');
      expect(
        first.shelves.first.books.map((b) => b.id),
        ['e1', 'e2', 'e3'],
      );
    });

    test('1.19.0 kuralı: favoriler yayınevi kriterinde tamamen yok sayılır', () {
      // Favori raf + favori yazar kayıtlı ama kriter yayınevi: favori
      // raf REZERVE EDİLMEZ, favori yazar kitapları havuzdan çıkarılmaz;
      // plan yalnız yayınevine göre kurulur (kendi başına çalışır).
      final books = [
        book('e1', authors: ['Ece Temelkuran'], publisher: 'Can'),
        book('e2', authors: ['Ece Temelkuran'], publisher: 'Can'),
        book('a1', authors: ['Ahmet Ümit'], publisher: 'İletişim'),
      ];
      final withFavorites = ShelfPlanner.arrange(
        books,
        [shelf('A', 10, order: 0), shelf('B', 10, order: 1)],
        OrganizeCriterion.publisher,
        options: const OrganizeOptions(
          favoriteShelfId: 'shelf-A',
          favoriteAuthors: ['Ece Temelkuran'],
        ),
      );
      final withoutFavorites = ShelfPlanner.arrange(
        books,
        [shelf('A', 10, order: 0), shelf('B', 10, order: 1)],
        OrganizeCriterion.publisher,
      );

      String signature(ShelfArrangement a) => [
            for (final planned in a.shelves)
              '${planned.shelf.name}:${planned.books.map((b) => b.id).join(",")}',
          ].join('|');
      expect(signature(withFavorites), signature(withoutFavorites));
      // Favori rafa yalnız favori kitaplar konmuş olsaydı Can kitapları
      // A'da olurdu; yok sayıldığı için Can grubu çoktan aza ilk sığan
      // rafa gider ve favori uyarısı ÜRETİLMEZ.
      expect(withFavorites.warnings.join(' '),
          isNot(contains('favori yazarların')));
      // Can (2 kitap) ve İletişim (1) sırayla ilk rafa yerleşir; favori
      // rezervasyonu olmadığı için A rafında Can kitapları NORMAL yerinde.
      expect(
        withFavorites.shelves[0].books.map((b) => b.id),
        withoutFavorites.shelves[0].books.map((b) => b.id),
      );
    });
  });
}

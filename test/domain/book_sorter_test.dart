import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/services/book_sort.dart';

/// Bellek içi kitap üretici; yalnız testte ilgi alanı olan alanlar doldurulur.
BookModel b(
  String id, {
  String title = 'Kitap',
  List<String> authors = const [],
  String? publisher,
  String shelf = '',
  int pageCount = 0,
  int currentPage = 0,
  DateTime? startedAt,
  DateTime? finishedAt,
  String? publishDate,
}) =>
    BookModel(
      id: id,
      title: title,
      authors: authors,
      publisher: publisher,
      shelf: shelf,
      pageCount: pageCount,
      currentPage: currentPage,
      startedAt: startedAt,
      finishedAt: finishedAt,
      publishDate: publishDate,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('kitap adı', () {
    test('Türkçe alfabeyle artan sıralar (ç < ı < i < z)', () {
      final books = [
        b('1', title: 'Zebra'),
        b('2', title: 'İzmir'),
        b('3', title: 'Işık'),
        b('4', title: 'Çiçek'),
      ];

      BookSorter.sort(books, BookSortField.title, true);

      expect(books.map((e) => e.id).toList(), ['4', '3', '2', '1']);
    });

    test('azalan sıra tam tersi olur', () {
      final books = [
        b('1', title: 'Ada'),
        b('2', title: 'Zebra'),
      ];

      BookSorter.sort(books, BookSortField.title, false);

      expect(books.map((e) => e.id).toList(), ['2', '1']);
    });
  });

  group('yazar', () {
    test('çok yazarlı kitap ilk (birincil) yazara göre sıralanır', () {
      final books = [
        b('1', authors: ['Yılmaz Gruda', 'Ahmet Erhan']),
        b('2', authors: ['Orhan Pamuk']),
        b('3', authors: ['Franz Kafka']),
      ];

      BookSorter.sort(books, BookSortField.author, true);

      expect(books.map((e) => e.id).toList(), ['3', '2', '1']);
    });

    test('yazarsız kitaplar her iki yönde de sonda kalır', () {
      final books = [
        b('1'),
        b('2', authors: ['Zeynep A']),
        b('3', authors: ['Ahmet B']),
      ];

      BookSorter.sort(books, BookSortField.author, true);
      expect(books.map((e) => e.id).toList(), ['3', '2', '1']);

      BookSorter.sort(books, BookSortField.author, false);
      expect(books.map((e) => e.id).toList(), ['2', '3', '1']);
    });
  });

  group('yayınevi', () {
    test('yayınevi adına göre artan sıralar, yayınevisiz sonda', () {
      final books = [
        b('1', publisher: 'Yapı Kredi'),
        b('2', publisher: null),
        b('3', publisher: 'Can Yayınları'),
      ];

      BookSorter.sort(books, BookSortField.publisher, true);
      expect(books.map((e) => e.id).toList(), ['3', '1', '2']);

      BookSorter.sort(books, BookSortField.publisher, false);
      expect(books.map((e) => e.id).toList(), ['1', '3', '2']);
    });
  });

  group('raf', () {
    test('raf adına göre Türkçe sıralar, rafsız sonda', () {
      final books = [
        b('1', shelf: 'Salon'),
        b('2', shelf: ''),
        b('3', shelf: 'Çalışma'),
      ];

      BookSorter.sort(books, BookSortField.shelf, true);
      expect(books.map((e) => e.id).toList(), ['3', '1', '2']);

      BookSorter.sort(books, BookSortField.shelf, false);
      expect(books.map((e) => e.id).toList(), ['1', '3', '2']);
    });
  });

  group('sayfa sayısı', () {
    test('bilinmeyen (0) her iki yönde de sonda; bilinenler sayısal', () {
      final books = [
        b('1', pageCount: 300),
        b('2', pageCount: 0),
        b('3', pageCount: 120),
      ];

      BookSorter.sort(books, BookSortField.pageCount, true);
      expect(books.map((e) => e.id).toList(), ['3', '1', '2']);

      BookSorter.sort(books, BookSortField.pageCount, false);
      expect(books.map((e) => e.id).toList(), ['1', '3', '2']);
    });
  });

  group('okunulan sayfa', () {
    test('0 gerçek bir değerdir ve sıralamaya girer', () {
      final books = [
        b('1', currentPage: 120),
        b('2', currentPage: 0),
        b('3', currentPage: 50),
      ];

      BookSorter.sort(books, BookSortField.currentPage, true);
      expect(books.map((e) => e.id).toList(), ['2', '3', '1']);

      BookSorter.sort(books, BookSortField.currentPage, false);
      expect(books.map((e) => e.id).toList(), ['1', '3', '2']);
    });
  });

  group('başlama ve bitirme tarihi', () {
    test('tarihsiz kitaplar her iki yönde de sonda kalır', () {
      final books = [
        b('1', startedAt: DateTime(2026, 3, 1)),
        b('2'),
        b('3', startedAt: DateTime(2026, 1, 10)),
      ];

      BookSorter.sort(books, BookSortField.startedAt, true);
      expect(books.map((e) => e.id).toList(), ['3', '1', '2']);

      BookSorter.sort(books, BookSortField.startedAt, false);
      expect(books.map((e) => e.id).toList(), ['1', '3', '2']);
    });

    test('bitirme tarihi kronolojik sıralanır, bitmemişler sonda', () {
      final books = [
        b('1', finishedAt: DateTime(2026, 2, 1)),
        b('2', finishedAt: DateTime(2025, 12, 30)),
        b('3'),
      ];

      BookSorter.sort(books, BookSortField.finishedAt, true);
      expect(books.map((e) => e.id).toList(), ['2', '1', '3']);

      BookSorter.sort(books, BookSortField.finishedAt, false);
      expect(books.map((e) => e.id).toList(), ['1', '2', '3']);
    });
  });

  group('basım tarihi', () {
    test('serbest metinden yılı ayıklayıp yıl sırasına dizer', () {
      final books = [
        b('1', publishDate: 'October 1, 2005'),
        b('2', publishDate: 'Mayıs 1999'),
        b('3', publishDate: '2005'),
      ];

      BookSorter.sort(books, BookSortField.publishDate, true);
      // 1999 birincil; aynı yıl (2005) kalanlar metin sırasıyla:
      // 'o' harfi, alfabe dışı rakamlardan ('2') önce gelir.
      expect(books.map((e) => e.id).toList(), ['2', '1', '3']);

      BookSorter.sort(books, BookSortField.publishDate, false);
      expect(books.map((e) => e.id).toList(), ['3', '1', '2']);
    });

    test('yılsız metin ve boş basım tarihi sonda kalır', () {
      final books = [
        b('1', publishDate: null),
        b('2', publishDate: 'Baskı bilgisi yok'),
        b('3', publishDate: '1973'),
      ];

      BookSorter.sort(books, BookSortField.publishDate, true);
      expect(books.map((e) => e.id).toList(), ['3', '1', '2']);

      BookSorter.sort(books, BookSortField.publishDate, false);
      expect(books.map((e) => e.id).toList(), ['3', '1', '2']);
    });
  });

  group('eksiklik ve eşitlik kuralları', () {
    test('isMissing alan bazlı çalışır', () {
      expect(
        BookSorter.isMissing(b('1', pageCount: 0), BookSortField.pageCount),
        isTrue,
      );
      expect(
        BookSorter.isMissing(b('1', currentPage: 0), BookSortField.currentPage),
        isFalse,
      );
      expect(
        BookSorter.isMissing(
          b('1', publishDate: '1973'),
          BookSortField.publishDate,
        ),
        isFalse,
      );
      expect(
        BookSorter.isMissing(b('1', shelf: ''), BookSortField.shelf),
        isTrue,
      );
    });

    test('birincil alan eşitken sıra kitap adına göre kırılır', () {
      final books = [
        b('1', title: 'Zorba', pageCount: 300),
        b('2', title: 'Ada', pageCount: 300),
      ];

      BookSorter.sort(books, BookSortField.pageCount, true);
      expect(books.map((e) => e.id).toList(), ['2', '1']);

      // Birincil eşit olduğu için kırıcı yön ters çevirse de ad sırası
      // kalır: sonuç kararlı ve öngörülebilir.
      BookSorter.sort(books, BookSortField.pageCount, false);
      expect(books.map((e) => e.id).toList(), ['2', '1']);
    });

    test('compare çift yönlü tutarlıdır', () {
      final a = b('1', pageCount: 100);
      final z = b('2', pageCount: 500);

      final asc = BookSorter.compare(a, z, BookSortField.pageCount, true);
      final desc = BookSorter.compare(a, z, BookSortField.pageCount, false);

      expect(asc, lessThan(0));
      expect(desc, greaterThan(0));
      expect(asc, -desc);
    });
  });
}

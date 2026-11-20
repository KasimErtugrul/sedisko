import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/open_library_search_result.dart';
import 'package:kitaplik/data/models/wishlist_item_model.dart';

/// WishlistItemModel ve OpenLibrarySearchResult ayrıştırma/çevrim
/// davranışları (1.18.0).
void main() {
  group('WishlistSource', () {
    test('fromKey: bilinen anahtarlar ve güvenli varsayılan', () {
      expect(WishlistSource.fromKey('openlibrary'), WishlistSource.openlibrary);
      expect(WishlistSource.fromKey('manual'), WishlistSource.manual);
      expect(WishlistSource.fromKey('bilinmeyen'), WishlistSource.manual);
      expect(WishlistSource.fromKey(null), WishlistSource.manual);
    });

    test('label: kullanıcıya gösterilen metin', () {
      expect(WishlistSource.openlibrary.label, 'Open Library');
      expect(WishlistSource.manual.label, 'Manuel');
    });
  });

  group('WishlistItemModel json', () {
    WishlistItemModel item() => WishlistItemModel(
          id: 'w1',
          title: 'Dune',
          authors: ['Frank Herbert'],
          isbn: '9780441172719',
          publisher: 'Ace Books',
          pageCount: 412,
          coverUrl: 'https://covers.openlibrary.org/b/id/1-M.jpg',
          note: 'okurken önerildi',
          addedAt: DateTime.parse('2026-01-02T10:00:00.000'),
          source: WishlistSource.openlibrary,
        );

    test('toJson → tryFromJson roundtrip korunur', () {
      final restored = WishlistItemModel.tryFromJson(item().toJson());
      expect(restored, item());
    });

    test('tryFromJson: id veya title eksikse null', () {
      expect(
        WishlistItemModel.tryFromJson({'title': 'idsiz'}),
        isNull,
      );
      expect(
        WishlistItemModel.tryFromJson({'id': 'w1'}),
        isNull,
      );
    });

    test('tryFromJson savunmacı: bozuk tipler varsayılana düşer', () {
      final restored = WishlistItemModel.tryFromJson({
        'id': 'w1',
        'title': 'Dune',
        'authors': 'liste değil',
        'pageCount': 'sayı değil',
        'addedAt': 'tarih değil',
        'source': 'anlaşılmayan kaynak',
      });

      expect(restored, isNotNull);
      expect(restored!.authors, isEmpty);
      expect(restored.pageCount, 0);
      expect(restored.source, WishlistSource.manual);
    });

    test('fromJson bozuk kayıtta FormatException fırlatır', () {
      expect(
        () => WishlistItemModel.fromJson({'title': 'idsiz'}),
        throwsFormatException,
      );
    });

    test('source anahtarı string olarak yazılır', () {
      final json = item().toJson();
      expect(json['source'], 'openlibrary');
      expect(json['addedAt'], '2026-01-02T10:00:00.000');
    });
  });

  group('WishlistItemModel copyWith', () {
    test('verilmeyen alanlar korunur', () {
      final item = WishlistItemModel(
        id: 'w1',
        title: 'Dune',
        isbn: '9780441172719',
        coverUrl: 'kapak',
        note: 'not',
        addedAt: DateTime(2026, 1, 1),
      );

      final updated = item.copyWith(title: 'Dune Yeni');

      expect(updated.title, 'Dune Yeni');
      expect(updated.isbn, '9780441172719');
      expect(updated.coverUrl, 'kapak');
      expect(updated.note, 'not');
      expect(updated.addedAt, item.addedAt);
    });

    test('null verilirse alan temizlenir (sentinel deseni)', () {
      final item = WishlistItemModel(
        id: 'w1',
        title: 'Dune',
        isbn: '9780441172719',
        coverUrl: 'kapak',
        note: 'not',
        addedAt: DateTime(2026, 1, 1),
      );

      final updated = item.copyWith(note: null, coverUrl: null, isbn: null);

      expect(updated.note, isNull);
      expect(updated.coverUrl, isNull);
      expect(updated.isbn, isNull);
    });
  });

  group('WishlistItemModel toBook', () {
    test('alanlar BookModel\'e taşınır, isManual true', () {
      final item = WishlistItemModel(
        id: 'w1',
        title: 'Dune',
        authors: ['Frank Herbert'],
        isbn: '9780441172719',
        publisher: 'Ace Books',
        pageCount: 412,
        coverUrl: 'kapak',
        addedAt: DateTime(2026, 1, 1),
      );

      final book = item.toBook();

      expect(book.id, isNot('w1'));
      expect(book.id, isNotEmpty);
      expect(book.title, 'Dune');
      expect(book.authors, ['Frank Herbert']);
      expect(book.isbn, '9780441172719');
      expect(book.publisher, 'Ace Books');
      expect(book.pageCount, 412);
      expect(book.coverUrl, 'kapak');
      expect(book.isManual, isTrue);
    });

    test('newId çakışmaz', () {
      expect(WishlistItemModel.newId(), isNot(WishlistItemModel.newId()));
    });
  });

  group('OpenLibrarySearchResult', () {
    test('tryFromJson: eksik/boş title null döner', () {
      expect(
        OpenLibrarySearchResult.tryFromJson({'author_name': ['X']}),
        isNull,
      );
      expect(
        OpenLibrarySearchResult.tryFromJson({'title': ''}),
        isNull,
      );
    });

    test('tryFromJson savunmacı ayrıştırma', () {
      final result = OpenLibrarySearchResult.tryFromJson({
        'title': 'Dune',
        'author_name': 'liste değil',
        'publisher': null,
        'isbn': null,
        'first_publish_year': 'sayı değil',
        'cover_i': 'yok',
        'number_of_pages_median': 'yok',
      });

      expect(result, isNotNull);
      expect(result!.authors, isEmpty);
      expect(result.publishers, isEmpty);
      expect(result.isbns, isEmpty);
      expect(result.firstPublishYear, isNull);
      expect(result.coverId, isNull);
      expect(result.pageCount, isNull);
    });

    test('toBook: tüm alanlar taşınır', () {
      final result = OpenLibrarySearchResult(
        title: 'Dune',
        authors: ['Frank Herbert'],
        firstPublishYear: 1965,
        coverId: 846192,
        isbns: ['0140328726', '9780140328721'],
        publishers: ['Chilton Books', 'Ace Books'],
        pageCount: 412,
      );

      final book = result.toBook();

      expect(book.title, 'Dune');
      expect(book.authors, ['Frank Herbert']);
      // 13 haneli ISBN tercih edilir.
      expect(book.isbn, '9780140328721');
      expect(book.coverUrl, 'https://covers.openlibrary.org/b/id/846192-M.jpg');
      expect(book.publisher, 'Chilton Books');
      expect(book.publishDate, '1965');
      expect(book.pageCount, 412);
      expect(book.id, isNotEmpty);
    });

    test('_pickIsbn: 13 hane yoksa ilk ISBN; hiç yoksa null', () {
      expect(
        OpenLibrarySearchResult(title: 'A', isbns: ['0140328726']).toBook().isbn,
        '0140328726',
      );
      expect(
        OpenLibrarySearchResult(title: 'A', isbns: []).toBook().isbn,
        isNull,
      );
    });

    test('toBook: kapak yoksa coverUrl null, sayfa 0', () {
      final book = OpenLibrarySearchResult(title: 'Kapaksız').toBook();
      expect(book.coverUrl, isNull);
      expect(book.pageCount, 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';

void main() {
  group('BookModel.fromJson / toJson', () {
    test('JSON gidiş-dönüşte veri kaybı yapmaz', () {
      final book = BookModel(
        id: 'a1',
        title: 'Simyacı',
        authors: const ['Paulo Coelho'],
        isbn: '9789752115037',
        coverUrl: 'https://covers.openlibrary.org/x.jpg',
        publisher: 'Altın Kitaplar',
        publishDate: '1996',
        pageCount: 188,
        shelf: 'Çalışma',
        status: ReadingStatus.finished,
        currentPage: 188,
        startedAt: DateTime(2024, 1, 5, 10, 30),
        finishedAt: DateTime(2024, 1, 20, 22, 0),
        notes: 'Çok sevdim',
        isManual: false,
        addedAt: DateTime(2024, 1, 5, 10),
      );

      final restored = BookModel.fromJson(book.toJson());

      expect(restored, book); // Equatable eşitliği
      expect(restored.startedAt, DateTime(2024, 1, 5, 10, 30));
      expect(restored.finishedAt, DateTime(2024, 1, 20, 22, 0));
    });

    test('eksik alanlar için güvenli varsayılanlar kullanır', () {
      final book = BookModel.fromJson({'id': 'x2'});
      expect(book.title, '');
      expect(book.authors, isEmpty);
      expect(book.status, ReadingStatus.notStarted);
      expect(book.pageCount, 0);
      expect(book.isManual, false);
    });

    test('bozuk tip: authors string / pageCount string gelse de patlamaz', () {
      final book = BookModel.fromJson({
        'id': 'x3',
        'authors': 'tek yazar',
        'pageCount': 'değil',
      });
      expect(book.authors, isEmpty);
      expect(book.pageCount, 0);
    });

    test('tryFromJson: id yoksa/hatalıysa null döner', () {
      expect(BookModel.tryFromJson({'title': 'idsiz'}), isNull);
      expect(BookModel.tryFromJson({'id': 42}), isNull);
      expect(BookModel.tryFromJson({'id': ''}), isNull);
    });

    test('tryFromJson: id string ise kaydı döner', () {
      final book = BookModel.tryFromJson({'id': 'ok', 'title': 'Dune'});
      expect(book, isNotNull);
      expect(book!.title, 'Dune');
    });
  });

  group('BookModel.fromOpenLibrary', () {
    test('authors/publishers/cover ayrıştırır', () {
      final book = BookModel.fromOpenLibrary('9783161484100', {
        'title': 'Eine kurze Geschichte der Zeit',
        'authors': [
          {'name': 'Stephen Hawking'},
          {'name': null},
          'Sadece İsim',
        ],
        'publishers': [
          {'name': 'Rowohlt'},
        ],
        'cover': {'small': 'https://small.jpg', 'medium': 'https://mid.jpg'},
        'number_of_pages': 212,
        'publish_date': '1988',
      });

      expect(book.title, 'Eine kurze Geschichte der Zeit');
      expect(book.authors, ['Stephen Hawking', 'Sadece İsim']);
      expect(book.publisher, 'Rowohlt');
      expect(book.coverUrl, 'https://mid.jpg'); // medium öncelikli
      expect(book.pageCount, 212);
      expect(book.publishDate, '1988');
      expect(book.isbn, '9783161484100');
    });

    test('boş/eksik alanlar null ya da boş kalır', () {
      final book = BookModel.fromOpenLibrary('9783161484100', {});
      expect(book.title, '');
      expect(book.authors, isEmpty);
      expect(book.publisher, isNull);
      expect(book.coverUrl, isNull);
    });
  });

  group('BookModel.copyWith', () {
    test('tarih null verilirse temizler, verilmezse korur', () {
      final base = BookModel(
        id: 'c1',
        title: 'T',
        addedAt: DateTime(2024, 3, 1),
        startedAt: DateTime(2024, 3, 2),
        finishedAt: DateTime(2024, 3, 3),
      );

      final cleared =
          base.copyWith(status: ReadingStatus.reading, finishedAt: null);
      expect(cleared.finishedAt, isNull);
      expect(cleared.startedAt, DateTime(2024, 3, 2));

      final untouched = base.copyWith(status: ReadingStatus.reading);
      expect(untouched.finishedAt, DateTime(2024, 3, 3));
    });
  });

  group('BookModel.progress', () {
    test('pageCount 0 ise progress 0 döner', () {
      final book = BookModel(
        id: 'p1',
        title: 'T',
        addedAt: DateTime(2024, 1, 1),
        currentPage: 50,
      );
      expect(book.progress, 0);
    });

    test('progress 0-1 aralığına sabitlenir', () {
      final book = BookModel(
        id: 'p2',
        title: 'T',
        addedAt: DateTime(2024, 1, 1),
        pageCount: 100,
        currentPage: 250, // olası bozuk veri
      );
      expect(book.progress, 1.0);
    });
  });

  group('BookModel.newId', () {
    test('ardışık çağrılar çakışmaz', () {
      final ids = <String>{for (var i = 0; i < 1000; i++) BookModel.newId()};
      expect(ids.length, 1000);
    });
  });
}

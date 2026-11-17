import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/utils/text_normalizer.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';

/// Yazar filtresi ve kopya (aynı ISBN) testleri.
class FakeBookRepository implements BookRepository {
  FakeBookRepository({List<BookModel>? initial}) : store = [...?initial];

  final List<BookModel> store;

  @override
  Future<List<BookModel>> getBooks() async => [...store];

  @override
  Future<void> saveBook(BookModel book) async {
    final index = store.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      store[index] = book;
    } else {
      store.add(book);
    }
  }

  @override
  Future<void> deleteBook(String id) async =>
      store.removeWhere((b) => b.id == id);

  @override
  Future<BookModel?> fetchBookByIsbn(String isbn) async => null;
}

BookModel seed(
  String id,
  String title, {
  List<String> authors = const [],
  String shelf = '',
  String? isbn,
}) =>
    BookModel(
      id: id,
      title: title,
      authors: authors,
      shelf: shelf,
      isbn: isbn,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  late FakeBookRepository repository;
  late LibraryController controller;

  setUp(() {
    Get.testMode = true;
    repository = FakeBookRepository(initial: [
      seed(
        'b1',
        'Benim Adım Kırmızı',
        authors: ['Orhan Pamuk'],
        shelf: 'Roman',
        isbn: '978-3-16-148410-0',
      ),
      seed(
        'b2',
        'Simyacı',
        authors: ['orhan pamuk'], // büyük harf/aksan farkı: aynı yazar grubu
        shelf: 'Tarih',
        isbn: '9783161484100', // kirli biçim: b1 ile aynı ISBN
      ),
      seed(
        'b3',
        'Dönüşüm',
        authors: ['Franz Kafka'],
        shelf: 'Roman',
      ),
      seed('b4', 'Not Defteri', authors: [], shelf: ''),
    ]);
    controller = LibraryController(repository, onNotify: (_, __) {});
    controller.books.assignAll(repository.store);
  });

  tearDown(() {
    Get.reset();
  });

  group('authors', () {
    test('yazım farklarını birleştirir ve Türkçe sıralar', () {
      expect(controller.authors, ['Franz Kafka', 'Orhan Pamuk']);
    });

    test('boş yazar listesi kitaplığı kirletmez', () {
      // b4'ün yazarı yok; authors'a boş ad sızamaz.
      expect(controller.authors, everyElement(isNotEmpty));
    });
  });

  group('authorDisplayName', () {
    test('ilk görülen yazımı döner', () {
      final key = TextNormalizer.searchKey('ORHAN PAMUK');
      expect(controller.authorDisplayName(key), 'Orhan Pamuk');
    });

    test('bilinmeyen anahtar null döner', () {
      expect(controller.authorDisplayName('yok-boyle-yazar'), isNull);
    });
  });

  group('authorFilter', () {
    final orhanKey = TextNormalizer.searchKey; // kullanım kolaylığı

    test('aktifken yalnız o yazarın kitapları döner', () {
      controller.authorFilter.value = orhanKey('Orhan Pamuk');

      final result = controller.filteredBooks();
      expect(result.map((b) => b.id).toSet(), {'b1', 'b2'});
    });

    test('raf filtresiyle birlikte çalışır', () {
      controller.authorFilter.value = orhanKey('Orhan Pamuk');

      final result = controller.filteredBooks(shelf: 'Roman');
      expect(result.map((b) => b.id), ['b1']);
    });

    test('Türkçe büyük harf yazımıyla aynı grubu seçer', () {
      // Kullanıcı 'ORHAN PAMUK' yazmış gibi: searchKey eşleşmesi sayesinde
      // aynı gruba düşer.
      controller.authorFilter.value = orhanKey('ORHAN PAMUK');
      expect(controller.filteredBooks().length, 2);
    });

    test('null iken tüm kitaplar döner', () {
      expect(controller.filteredBooks().length, 4);
    });
  });

  group('copiesOf', () {
    test('kirli biçim farkını yoksayıp aynı ISBN\'i kopya sayar', () {
      final copies = controller.copiesOf(controller.byId('b1')!);
      expect(copies.map((b) => b.id), ['b2']);
    });

    test('kendisini kopya saymaz', () {
      final copies = controller.copiesOf(controller.byId('b2')!);
      expect(copies.map((b) => b.id), ['b1']);
    });

    test('ISBN\'i olmayan kitapların kopyası aranmaz', () {
      expect(controller.copiesOf(controller.byId('b3')!), isEmpty);
      expect(controller.copiesOf(controller.byId('b4')!), isEmpty);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';

class FakeBookRepository implements BookRepository {
  final List<BookModel> store;

  FakeBookRepository({List<BookModel>? initial}) : store = [...?initial];

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

void main() {
  late FakeBookRepository repository;
  late LibraryController controller;

  setUp(() {
    Get.testMode = true;
    repository = FakeBookRepository(initial: [
      BookModel(
        id: 'b1',
        title: 'Denizler Altında',
        shelf: 'Roman',
        addedAt: DateTime(2026, 1, 1),
      ),
      BookModel(
        id: 'b2',
        title: 'Kürk Mantolu Madonna',
        shelf: 'Roman',
        addedAt: DateTime(2026, 1, 2),
      ),
      BookModel(
        id: 'b3',
        title: 'Osmanlı Tarihi',
        shelf: 'Tarih',
        addedAt: DateTime(2026, 1, 3),
      ),
      BookModel(
        id: 'b4',
        title: 'Not Defteri',
        shelf: '',
        addedAt: DateTime(2026, 1, 4),
      ),
    ]);
    controller = LibraryController(repository, onNotify: (_, __) {});
    controller.books.assignAll(repository.store);
  });

  tearDown(() {
    Get.reset();
  });

  group('filteredBooks', () {
    test('shelf verilmezse tüm kitaplar döner', () {
      expect(controller.filteredBooks(), hasLength(4));
    });

    test('raf adı yalnız o raftaki kitapları döner', () {
      final result = controller.filteredBooks(shelf: 'Roman');

      expect(result, hasLength(2));
      expect(result.every((b) => b.shelf.trim() == 'Roman'), isTrue);
    });

    test("'Rafsız' rafsız kitapları döner", () {
      final result = controller.filteredBooks(shelf: 'Rafsız');

      expect(result, hasLength(1));
      expect(result.single.title, 'Not Defteri');
    });

    test('olmayan raf adı boş liste döner', () {
      expect(controller.filteredBooks(shelf: 'Şiir'), isEmpty);
    });

    test('raf filtresi arama ve durum filtresiyle birleşir', () {
      controller.query.value = 'madonna';

      expect(
        controller.filteredBooks(shelf: 'Roman').single.title,
        'Kürk Mantolu Madonna',
      );

      // 'Tarih' rafında 'madonna' eşleşmesi yok: boş.
      expect(controller.filteredBooks(shelf: 'Tarih'), isEmpty);
      controller.statusFilter.value = ReadingStatus.reading;
      controller.query.value = '';
      expect(controller.filteredBooks(shelf: 'Roman'), isEmpty);
    });

    test('raf filtresi boşluklu raf adını kırparak eşleştirir', () {
      controller.books[3] = controller.books[3].copyWith(shelf: '  ');

      expect(controller.filteredBooks(shelf: 'Rafsız'), hasLength(1));
    });
  });

  group('shelfKeys', () {
    test('dolu raflar Türkçe sıralı, Rafsız sonda', () {
      expect(controller.shelfKeys, ['Roman', 'Tarih', 'Rafsız']);
    });

    test('her kitap rafındayken Rafsız anahtarı yoktur', () {
      controller.books[3] = controller.books[3].copyWith(shelf: 'Tarih');

      expect(controller.shelfKeys, ['Roman', 'Tarih']);
    });
  });

  group('shelfCount', () {
    test('raf başına kitap sayısını verir', () {
      expect(controller.shelfCount('Roman'), 2);
      expect(controller.shelfCount('Tarih'), 1);
      expect(controller.shelfCount('Rafsız'), 1);
      expect(controller.shelfCount('Şiir'), 0);
    });
  });
}

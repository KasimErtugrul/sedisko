import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/domain/services/book_sort.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';

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

void main() {
  late FakeBookRepository repository;
  late LibraryController controller;

  setUp(() {
    Get.testMode = true;
    repository = FakeBookRepository(initial: [
      BookModel(
        id: 'b1',
        title: 'Dune',
        shelf: 'Roman',
        pageCount: 412,
        currentPage: 120,
        addedAt: DateTime(2026, 1, 1),
      ),
      BookModel(
        id: 'b2',
        title: 'Simyacı',
        shelf: 'Roman',
        pageCount: 184,
        addedAt: DateTime(2026, 1, 2),
      ),
      BookModel(
        id: 'b3',
        title: 'Dönüşüm',
        shelf: 'Tarih',
        pageCount: 96,
        addedAt: DateTime(2026, 1, 3),
      ),
      // Sayfa sayısı bilinmeyen (0) + rafsız: eksiklik davranışının kanıtı.
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

  group('varsayılan sıralama', () {
    test('kitap adı artandır', () {
      expect(controller.sortField.value, BookSortField.title);
      expect(controller.sortAscending.value, isTrue);
      expect(controller.hasCustomSort, isFalse);

      // Türkçe alfabe: Dönüşüm (ö) < Dune (u).
      expect(
        controller.filteredBooks().map((b) => b.id).toList(),
        ['b3', 'b1', 'b4', 'b2'],
      );
    });
  });

  group('setSort', () {
    test('alan + yön verildiğinde listeyi o düzene sokar', () {
      controller.setSort(BookSortField.pageCount, ascending: false);

      // Bilinenler azalan; bilinmeyen (b4) her iki yönde sonda.
      expect(
        controller.filteredBooks().map((b) => b.id).toList(),
        ['b1', 'b2', 'b3', 'b4'],
      );

      controller.setSort(BookSortField.pageCount, ascending: true);
      expect(
        controller.filteredBooks().map((b) => b.id).toList(),
        ['b3', 'b2', 'b1', 'b4'],
      );
    });

    test('yön verilmezse aynı alan yönü çevirir, yeni alan artan başlar',
        () {
      controller.setSort(BookSortField.pageCount, ascending: false);
      expect(controller.sortAscending.value, isFalse);

      // Aynı alan, yön vermeden: artana döner.
      controller.setSort(BookSortField.pageCount);
      expect(controller.sortField.value, BookSortField.pageCount);
      expect(controller.sortAscending.value, isTrue);

      // Yeni alan: varsayılan artan.
      controller.setSort(BookSortField.author);
      expect(controller.sortField.value, BookSortField.author);
      expect(controller.sortAscending.value, isTrue);
    });

    test('hasCustomSort yalnız varsayılan dışındayken true olur', () {
      controller.setSort(BookSortField.pageCount, ascending: true);
      expect(controller.hasCustomSort, isTrue);

      // Varsayılana dönüş: rozet kaybolur.
      controller.setSort(BookSortField.title, ascending: true);
      expect(controller.hasCustomSort, isFalse);
    });
  });

  group('sıralama ve filtre birleşimi', () {
    test('raf filtresiyle birlikte uygulanır', () {
      controller.setSort(BookSortField.currentPage, ascending: true);

      final roman = controller.filteredBooks(shelf: 'Roman');
      // Simyacı (0 sayfa, başlanmadı) önce, Dune (120) sonra.
      expect(roman.map((b) => b.id).toList(), ['b2', 'b1']);
    });

    test('sortedAll filtreleri yok sayar, sıralamayı uygular', () {
      controller.query.value = 'dune';
      controller.statusFilter.value = ReadingStatus.reading;
      controller.setSort(BookSortField.pageCount, ascending: false);

      // Filtreler yalnız filteredBooks'u daraltır.
      expect(controller.filteredBooks(), isEmpty);

      // sortedAll daima kitaplığın tamamını verir.
      expect(controller.sortedAll, hasLength(4));
      expect(
        controller.sortedAll.map((b) => b.id).toList(),
        ['b1', 'b2', 'b3', 'b4'],
      );
    });

    test('books listesinin raf/ada düzeni korunur', () async {
      // Kitap kartları ve bölümler bu düzene dayanır; sıralama yalnız
      // görünüm çıktısına (filteredBooks/sortedAll) uygulanır.
      await controller.loadBooks();

      expect(controller.books.map((b) => b.id).toList(), [
        'b1',
        'b2', // Roman rafı, ad sırasıyla
        'b3', // Tarih rafı
        'b4', // rafsız: sonda
      ]);
    });
  });
}

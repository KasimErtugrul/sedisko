import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/errors/app_exceptions.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';

/// Raf taşıma testleri: tek kitap taşı, toplu taşı, günlük korunur.
class FakeBookRepository implements BookRepository {
  FakeBookRepository({List<BookModel>? initial}) : store = [...?initial];

  final List<BookModel> store;
  Object? throwOnSave;

  /// Yalnız bu id'li kitabın yazımında hata fırlat (kısmi toplu taşıma
  /// senaryosu için).
  String? throwOnSaveForId;

  @override
  Future<List<BookModel>> getBooks() async => [...store];

  @override
  Future<void> saveBook(BookModel book) async {
    final error = throwOnSave;
    if (error != null) throw error;
    if (book.id == throwOnSaveForId) throw const StorageException('Disk dolu');
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
    repository = FakeBookRepository();
    controller = LibraryController(repository, onNotify: (_, __) {});
  });

  tearDown(() {
    Get.reset();
  });

  BookModel book(
    String id, {
    String title = 'Kitap',
    String shelf = '',
    ReadingStatus status = ReadingStatus.notStarted,
    int pageCount = 0,
    int currentPage = 0,
  }) =>
      BookModel(
        id: id,
        title: title,
        shelf: shelf,
        status: status,
        pageCount: pageCount,
        currentPage: currentPage,
        addedAt: DateTime(2026, 1, 1),
      );

  group('moveToShelf', () {
    test('kitabı hedef rafa taşır ve depoya yazar', () async {
      await controller.saveBook(book('1', title: 'Dune', shelf: 'Roman'));

      final ok = await controller.moveToShelf(controller.byId('1')!, 'Tarih');

      expect(ok, isTrue);
      expect(controller.byId('1')!.shelf, 'Tarih');
      expect(repository.store.single.shelf, 'Tarih');
    });

    test('boş raf hedefi kitabı rafsız yapar', () async {
      await controller.saveBook(book('1', title: 'Dune', shelf: 'Roman'));

      await controller.moveToShelf(controller.byId('1')!, '');

      expect(controller.byId('1')!.shelf, '');
    });

    test('aynı rafa taşıma no-op durur', () async {
      await controller.saveBook(book('1', title: 'Dune', shelf: 'Roman'));
      final before = controller.byId('1')!;

      final ok = await controller.moveToShelf(before, 'Roman');

      expect(ok, isTrue);
      expect(controller.byId('1')!.shelf, 'Roman');
    });

    test('taşıma okuma durumunu değiştirmez', () async {
      final started = DateTime(2026, 1, 5);
      await controller.saveBook(BookModel(
        id: '1',
        title: 'Dune',
        shelf: 'Roman',
        status: ReadingStatus.reading,
        pageCount: 300,
        currentPage: 120,
        startedAt: started,
        addedAt: DateTime(2026, 1, 1),
      ));

      await controller.moveToShelf(controller.byId('1')!, 'Yatak Odası');

      final moved = controller.byId('1')!;
      expect(moved.status, ReadingStatus.reading);
      expect(moved.currentPage, 120);
      expect(moved.startedAt, started);
    });

    test('taşıma boş günlüğe referans kaydı EKLEMEZ', () async {
      // Günlük takibi başlamadan eklenmiş okunuyor kitap (eski veri):
      // günlüğü boş. Raf taşıma okuma olayı olmadığı için günlüğe dokunmaz.
      await controller.saveBook(book(
        '1',
        title: 'Dune',
        shelf: 'Roman',
        status: ReadingStatus.reading,
        pageCount: 300,
        currentPage: 120,
      ));
      expect(controller.byId('1')!.readingLog, hasLength(1)); // referans kaydı

      // Günlüğü elle boşalt (eski veri simülasyonu) ve taşı.
      final legacy = controller.byId('1')!.copyWith(readingLog: const []);
      await controller.saveBook(legacy, deriveLog: false);
      expect(controller.byId('1')!.readingLog, isEmpty);

      await controller.moveToShelf(controller.byId('1')!, 'Tarih');

      expect(controller.byId('1')!.readingLog, isEmpty);
      expect(repository.store.single.readingLog, isEmpty);
    });
  });

  group('moveManyToShelf', () {
    test('tüm kitapları tek rafa toplar ve sayıyı döner', () async {
      await controller.saveBook(book('1', title: 'A', shelf: 'Roman'));
      await controller.saveBook(book('2', title: 'B', shelf: 'Tarih'));
      await controller.saveBook(book('3', title: 'C', shelf: 'Rafsız'));

      final moved = await controller.moveManyToShelf(
        controller.books.toList(),
        'Yazar Rafı',
      );

      expect(moved, 3);
      expect(controller.books.every((b) => b.shelf == 'Yazar Rafı'), isTrue);
      expect(
        repository.store.every((b) => b.shelf == 'Yazar Rafı'),
        isTrue,
      );
    });

    test('zaten hedef rafta olanları atlar', () async {
      await controller.saveBook(book('1', title: 'A', shelf: 'Hedef'));
      await controller.saveBook(book('2', title: 'B', shelf: 'Başka'));
      await controller.saveBook(book('3', title: 'C', shelf: 'Başka'));

      final moved = await controller.moveManyToShelf(
        controller.books.toList(),
        'Hedef',
      );

      expect(moved, 2);
      expect(controller.byId('1')!.shelf, 'Hedef');
      expect(controller.byId('2')!.shelf, 'Hedef');
    });

    test('depoda hata varsa taşımayı keser ve kalanı dokunmaz bırakır',
        () async {
      // Raf adları Türkçe alfabe sırasında: K < L < M (yazma hatası ikinci
      // kitapta olduğundan ilki taşınır, kalanlar durur).
      await controller.saveBook(book('1', title: 'A', shelf: 'K'));
      await controller.saveBook(book('2', title: 'B', shelf: 'L'));
      await controller.saveBook(book('3', title: 'C', shelf: 'M'));
      repository.throwOnSaveForId = '2';

      final moved = await controller.moveManyToShelf(
        controller.books.toList(),
        'Z',
      );

      expect(moved, 1);
      expect(controller.byId('1')!.shelf, 'Z');
      expect(controller.byId('2')!.shelf, 'L');
      expect(controller.byId('3')!.shelf, 'M');
    });
  });
}

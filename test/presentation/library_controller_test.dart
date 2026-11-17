import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/errors/app_exceptions.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';

/// Bellek içi sahte repository; ağ/depoya dokunmaz.
class FakeBookRepository implements BookRepository {
  FakeBookRepository({List<BookModel>? initial}) : store = [...?initial];

  final List<BookModel> store;
  Object? throwOnSave;
  int fetchCallCount = 0;

  @override
  Future<List<BookModel>> getBooks() async => [...store];

  @override
  Future<void> saveBook(BookModel book) async {
    final error = throwOnSave;
    if (error != null) throw error;
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
  Future<BookModel?> fetchBookByIsbn(String isbn) async {
    fetchCallCount++;
    return null;
  }
}

void main() {
  late FakeBookRepository repository;
  late List<String> notifications;

  setUp(() {
    Get.testMode = true;
    repository = FakeBookRepository();
    notifications = [];
  });

  tearDown(() {
    Get.reset();
  });

  LibraryController buildController({FakeBookRepository? repo}) {
    final controller = LibraryController(
      repo ?? repository,
      onNotify: (title, message) => notifications.add('$title|$message'),
    );
    return controller;
  }

  BookModel book(
    String id, {
    String title = 'Kitap',
    String shelf = '',
    ReadingStatus status = ReadingStatus.notStarted,
    int pageCount = 0,
    int currentPage = 0,
    String? isbn,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) =>
      BookModel(
        id: id,
        title: title,
        shelf: shelf,
        status: status,
        pageCount: pageCount,
        currentPage: currentPage,
        isbn: isbn,
        startedAt: startedAt,
        finishedAt: finishedAt,
        addedAt: DateTime(2024, 1, 1),
      );

  group('loadBooks', () {
    test('depolanan kitapları yükler ve raf/ada göre sıralar', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [
          book('1', title: 'Zebra', shelf: 'B-raf'),
          book('2', title: 'Ant', shelf: 'A-raf'),
          book('3', title: 'Camka', shelf: 'A-raf'),
        ]),
      );

      await controller.loadBooks();

      expect(controller.books.map((b) => b.id).toList(), ['2', '3', '1']);
      expect(controller.isLoading.value, isFalse);
    });

    test('StorageException durumunda kullanıcıya bilgi gösterir', () async {
      // Repository arabirimi üzerinden hata; kullanıcı mesajı görülmeli.
      final failing = _ThrowingRepository(
        const StorageException('Depolama okunamadı'),
      );
      final controller = LibraryController(
        failing,
        onNotify: (t, m) => notifications.add('$t|$m'),
      );

      await controller.loadBooks();

      expect(notifications, isNotEmpty);
      expect(notifications.first, contains('yüklenemedi'));
      expect(controller.isLoading.value, isFalse);
    });
  });

  group('saveBook / deleteBook', () {
    test('yeni kitabı ekler ve true döner', () async {
      final controller = buildController();
      final ok = await controller.saveBook(book('1'));

      expect(ok, isTrue);
      expect(controller.books.length, 1);
      expect(repository.store.length, 1);
    });

    test('depodaki mevcut kitabı günceller', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [book('1', title: 'Eski')]),
      );
      await controller.loadBooks();

      final ok = await controller.saveBook(book('1', title: 'Yeni'));

      expect(ok, isTrue);
      expect(controller.books.single.title, 'Yeni');
    });

    test('yazma hatasında false döner ve bellek güncellenmez', () async {
      repository.throwOnSave = const StorageException('Disk dolu');
      final controller = buildController();

      final ok = await controller.saveBook(book('1'));

      expect(ok, isFalse);
      expect(controller.books, isEmpty);
      expect(notifications, isNotEmpty); // kullanıcıya hata gösterildi
    });

    test('deleteBook başarısızsa false döner', () async {
      final failing = _ThrowingRepository(null, deleteError: 'x');
      final controller = LibraryController(
        failing,
        onNotify: (t, m) => notifications.add('$t|$m'),
      );

      final ok = await controller.deleteBook('1');

      expect(ok, isFalse);
      expect(notifications, isNotEmpty);
    });
  });

  group('updateProgress', () {
    test('sayfa > 0 iken durumu Okunuyor yapar ve başlangıç tarihi atar',
        () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [book('1')]),
      );
      await controller.loadBooks();
      final target = controller.books.first;

      await controller.updateProgress(target, 42);

      final updated = controller.books.first;
      expect(updated.status, ReadingStatus.reading);
      expect(updated.currentPage, 42);
      expect(updated.startedAt, isNotNull);
      expect(updated.finishedAt, isNull);
    });

    test('son sayfaya gelince Bitti yapar ve bitiş tarihi atar', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [
          book('1', pageCount: 300, currentPage: 299),
        ]),
      );
      await controller.loadBooks();

      await controller.updateProgress(controller.books.first, 300);

      final updated = controller.books.first;
      expect(updated.status, ReadingStatus.finished);
      expect(updated.currentPage, 300);
      expect(updated.finishedAt, isNotNull);
    });

    test('sayfa sayısını aşan girişte kırpar', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [book('1', pageCount: 100)]),
      );
      await controller.loadBooks();

      await controller.updateProgress(controller.books.first, 500);

      expect(controller.books.first.currentPage, 100);
    });
  });

  group('arama ve filtreleme', () {
    test('Türkçe İ/ı fark etmeksizin arar', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [book('1', title: 'İstanbul Hatırası')]),
      );
      await controller.loadBooks();

      controller.query.value = 'istanbul';
      expect(controller.filteredBooks.length, 1);

      controller.query.value = 'İstanbul';
      expect(controller.filteredBooks.length, 1);
    });

    test('ISBN ile arar', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [
          book('1', title: 'Dune', isbn: '9783161484100'),
        ]),
      );
      await controller.loadBooks();

      controller.query.value = '316148';
      expect(controller.filteredBooks.length, 1);
    });

    test('durum filtresi uygular', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [
          book('1', title: 'A', status: ReadingStatus.reading),
          book('2', title: 'B', status: ReadingStatus.finished),
        ]),
      );
      await controller.loadBooks();

      controller.statusFilter.value = ReadingStatus.reading;
      expect(controller.filteredBooks.map((b) => b.id), ['1']);
    });
  });

  group('ISBN yardımcıları', () {
    test('findByIsbn kirli biçimlendirilmiş girdiyle eşleştirir', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [
          book('1', title: 'Dune', isbn: '9783161484100'),
        ]),
      );
      await controller.loadBooks();

      expect(controller.findByIsbn('978-3-16-148410-0')?.id, '1');
      expect(controller.findByIsbn('000'), isNull);
    });

    test('hasIsbnConflict: başka kitapta aynı ISBN varsa true', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [
          book('1', title: 'Dune', isbn: '9783161484100'),
        ]),
      );
      await controller.loadBooks();

      expect(controller.hasIsbnConflict('978-3-16-148410-0'), isTrue);
      expect(controller.hasIsbnConflict('9783161484100', exceptId: '1'), isFalse);
      expect(controller.hasIsbnConflict('9783161484100', exceptId: '2'), isTrue);
      expect(controller.hasIsbnConflict(''), isFalse);
    });
  });

  group('shelves', () {
    test('boş olmayan rafları Türkçe sırala ve tekilleştir', () async {
      final controller = buildController(
        repo: FakeBookRepository(initial: [
          book('1', shelf: 'Salon'),
          book('2', shelf: 'Çalışma'),
          book('3', shelf: 'Salon'),
          book('4', shelf: ''),
        ]),
      );
      await controller.loadBooks();

      // Türkçe alfabede Ç, S'den önce gelir.
      expect(controller.shelves, ['Çalışma', 'Salon']);
    });
  });
}

/// Belirli metodlarda hata fırlatan repository.
class _ThrowingRepository implements BookRepository {
  _ThrowingRepository(this.loadError, {this.deleteError});

  final Object? loadError;
  final Object? deleteError;

  @override
  Future<List<BookModel>> getBooks() async {
    final error = loadError;
    if (error != null) throw error;
    return [];
  }

  @override
  Future<void> saveBook(BookModel book) async {}

  @override
  Future<void> deleteBook(String id) async {
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Future<BookModel?> fetchBookByIsbn(String isbn) async => null;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';

/// Bellek içi sahte repository; yalnızca okuma günlüğü testleri için.
class FakeBookRepository implements BookRepository {
  final List<BookModel> store = [];

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
    repository = FakeBookRepository();
    controller = LibraryController(repository, onNotify: (_, __) {});
  });

  tearDown(() {
    Get.reset();
  });

  BookModel book({
    String id = 'b1',
    ReadingStatus status = ReadingStatus.notStarted,
    int pageCount = 300,
    int currentPage = 0,
  }) =>
      BookModel(
        id: id,
        title: 'Test Kitabı',
        pageCount: pageCount,
        status: status,
        currentPage: currentPage,
        addedAt: DateTime(2026, 1, 1),
      );

  /// Gerçek UI akışı: okumaya başla → ilerleme güncelle.
  /// Günlük: [0] → [0, 45]
  Future<void> saveReadingAndProgress() async {
    await controller.saveBook(book(status: ReadingStatus.reading));
    await controller.updateProgress(controller.books.first, 45);
  }

  test('saveBook okumaya başlanan kitaba referans kaydı ekler', () async {
    await controller.saveBook(book(status: ReadingStatus.reading));

    final log = controller.books.first.readingLog;
    expect(log, hasLength(1));
    expect(log.single.page, 0);
    // Depoya da birleşmiş kayıt gitmeli.
    expect(repository.store.single.readingLog, hasLength(1));
  });

  test('updateProgress ilerleme kaydı ekler', () async {
    await saveReadingAndProgress();

    final log = controller.books.first.readingLog;
    expect(log, hasLength(2));
    expect(log.last.page, 45);
  });

  test('Aynı sayfayla tekrar kayıt eklenmez', () async {
    await saveReadingAndProgress();
    final before = controller.books.first.readingLog.length;

    await controller.saveBook(
      controller.books.first.copyWith(title: 'Yeni başlık'),
    );

    expect(controller.books.first.readingLog, hasLength(before));
    expect(controller.books.first.title, 'Yeni başlık');
  });

  test('Sayfa elle geriye çekilirse kayıt eklenmez', () async {
    await saveReadingAndProgress();
    final before = controller.books.first.readingLog.length;

    await controller.updateProgress(controller.books.first, 30);

    expect(controller.books.first.readingLog, hasLength(before));
    expect(controller.books.first.currentPage, 30);
  });

  test('markFinished bitiş konumunu günlüğe işler', () async {
    await saveReadingAndProgress();

    await controller.markFinished(controller.books.first);

    final log = controller.books.first.readingLog;
    expect(log, hasLength(3));
    expect(log.last.page, 300);
    expect(controller.books.first.status, ReadingStatus.finished);
  });

  test('restartReading yeni tur için sıfır kaydı ekler', () async {
    await saveReadingAndProgress();
    await controller.markFinished(controller.books.first);

    await controller.restartReading(controller.books.first);

    final log = controller.books.first.readingLog;
    expect(log, hasLength(4));
    expect(log.last.page, 0);
    expect(controller.books.first.status, ReadingStatus.reading);
  });

  test('"Başlanmadı"ya dönüş günlüğü temizler', () async {
    await saveReadingAndProgress();
    expect(controller.books.first.readingLog, isNotEmpty);

    await controller.saveBook(
      controller.books.first.copyWith(
        status: ReadingStatus.notStarted,
        currentPage: 0,
        startedAt: null,
        finishedAt: null,
      ),
    );

    expect(controller.books.first.readingLog, isEmpty);
    expect(repository.store.single.readingLog, isEmpty);
  });

  test('Form tarzı kayıt (günlüksüz BookModel) mevcut günlüğü korur', () async {
    await saveReadingAndProgress();

    // Form, günlük alanını doldurmayan yeni bir BookModel üretir.
    final formModel = BookModel(
      id: 'b1',
      title: 'Test Kitabı',
      pageCount: 300,
      status: ReadingStatus.reading,
      currentPage: 90,
      addedAt: DateTime(2026, 1, 1),
    );
    await controller.saveBook(formModel);

    final log = controller.books.first.readingLog;
    expect(log, hasLength(3));
    expect(log.last.page, 90);
  });

  test('İkinci bitişte yeni kayıt eklenmez', () async {
    await saveReadingAndProgress();
    await controller.markFinished(controller.books.first);
    final before = controller.books.first.readingLog.length;

    await controller.markFinished(controller.books.first);

    expect(controller.books.first.readingLog, hasLength(before));
  });
}

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

BookModel seed({
  required String id,
  required String title,
  bool favorite = false,
  String notes = '',
  ReadingStatus status = ReadingStatus.notStarted,
}) {
  return BookModel(
    id: id,
    title: title,
    shelf: 'Raf',
    addedAt: DateTime(2026, 1, 1),
    isFavorite: favorite,
    notes: notes.isEmpty ? null : notes,
    status: status,
    startedAt: status == ReadingStatus.notStarted ? null : DateTime(2026, 1, 2),
  );
}

void main() {
  late FakeBookRepository repository;
  late LibraryController controller;

  setUp(() {
    Get.testMode = true;
    repository = FakeBookRepository(initial: [
      seed(id: 'b1', title: 'Simyacı', favorite: true),
      seed(id: 'b2', title: 'Şeker Portakalı', favorite: true),
      seed(id: 'b3', title: 'Dönüşüm', notes: 'Gregor Sabitov'),
      seed(
        id: 'b4',
        title: 'Fareler ve İnsanlar',
        status: ReadingStatus.reading,
        notes: 'Sayfa 40 notu',
      ),
      seed(id: 'b5', title: 'Hayvan Çiftliği', status: ReadingStatus.finished),
    ]);
    controller = LibraryController(repository, onNotify: (_, __) {});
    controller.books.assignAll(repository.store);
  });

  tearDown(() {
    Get.reset();
  });

  group('toggleFavorite', () {
    test('favori olmayan kitabı favoriye alır ve depoya yazar', () async {
      final book = controller.byId('b3')!;

      await controller.toggleFavorite(book);

      expect(controller.byId('b3')!.isFavorite, true);
      expect(repository.store.firstWhere((b) => b.id == 'b3').isFavorite, true);
    });

    test('favori kitabı favorilerden çıkarır', () async {
      final book = controller.byId('b1')!;

      await controller.toggleFavorite(book);

      expect(controller.byId('b1')!.isFavorite, false);
      expect(repository.store.firstWhere((b) => b.id == 'b1').isFavorite, false);
    });

    test('favori çevrimi okuma durumu ve sayfayı bozmaz', () async {
      final book = controller.byId('b4')!; // okunuyor + notlu

      await controller.toggleFavorite(book);

      final updated = controller.byId('b4')!;
      expect(updated.isFavorite, true);
      expect(updated.status, ReadingStatus.reading);
      expect(updated.currentPage, book.currentPage);
      expect(updated.notes, 'Sayfa 40 notu');
    });
  });

  group('ana sayfa bölüm sorguları', () {
    test('favoriteBooks yalnız favorileri döner', () {
      expect(
        controller.favoriteBooks.map((b) => b.id),
        ['b1', 'b2'],
      );
    });

    test('notedBooks yalnız notu dolu kitapları döner', () {
      expect(controller.notedBooks.map((b) => b.id), containsAll(['b3', 'b4']));
      expect(controller.notedBooks.map((b) => b.id), isNot(contains('b1')));
    });

    test('readingBooks yalnız okunuyor durumundakileri döner', () {
      expect(controller.readingBooks.map((b) => b.id), ['b4']);
      expect(controller.readingCount, 1);
    });

    test('finishedCount bitmiş kitapları sayar', () {
      expect(controller.finishedCount, 1);
    });

    test('toggleFavorite sonrası bölüm sorguları güncellenir', () async {
      await controller.toggleFavorite(controller.byId('b3')!);

      expect(controller.favoriteBooks.map((b) => b.id), contains('b3'));
    });
  });
}

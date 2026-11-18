import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/services/cover_photo_store.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
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
  test('kitap silinince fotoğraf dosyası da diskten silinir', () async {
    final tempRoot = await Directory.systemTemp.createTemp('lib_cleanup_test');
    addTearDown(() async {
      if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
    });
    final store = CoverPhotoStore(baseDir: () async => tempRoot);
    // Fotoğraf gerçek düzende covers/ klasörünün içinde olur.
    final coversDir =
        Directory('${tempRoot.path}${Platform.pathSeparator}covers');
    await coversDir.create(recursive: true);
    final photo =
        File('${coversDir.path}${Platform.pathSeparator}cover_x.jpg');
    await photo.writeAsBytes([1, 2, 3]);

    final repository = FakeBookRepository(initial: [
      BookModel(
        id: 'b1',
        title: 'Fotoğraflı',
        addedAt: DateTime(2026, 1, 1),
        coverPath: photo.path,
      ),
      BookModel(
        id: 'b2',
        title: 'Fotoğrafsız',
        addedAt: DateTime(2026, 1, 2),
      ),
    ]);
    final controller = LibraryController(
      repository,
      onNotify: (_, __) {},
      coverStore: store,
    );
    await controller.loadBooks();

    final ok = await controller.deleteBook('b1');

    expect(ok, isTrue);
    expect(controller.books.map((b) => b.id), ['b2']);
    expect(photo.existsSync(), isFalse);
  });

  test('coverStore verilmezse silme normal çalışır', () async {
    final repository = FakeBookRepository(initial: [
      BookModel(id: 'b3', title: 'T', addedAt: DateTime(2026, 1, 1)),
    ]);
    final controller = LibraryController(repository, onNotify: (_, __) {});
    await controller.loadBooks();

    final ok = await controller.deleteBook('b3');

    expect(ok, isTrue);
    expect(controller.books, isEmpty);
  });
}

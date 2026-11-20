import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/reading_log_entry.dart';
import 'package:kitaplik/data/services/cover_photo_store.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/pages/book_detail_page.dart';

/// Keşke 31 (1.23.0): "Sildiğim kitabı bir süre geri alabileydim —
/// 'Geri al şansı olsaydı, korkmadan kullanırdım.'" Silme, snackbar
/// üzerindeki "Geri Al" dokunuşuna kadar geri alınabilir: kitap AYNI
/// kimlikle (raf, okuma durumu, sayfa, günlük aynen) geri koyulur.
/// Süre dolunca silme gerçek olur (fotoğraf dosyası diskten silinir).
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

BookModel seed() => BookModel(
      id: 'b1',
      title: 'Dune',
      authors: ['Frank Herbert'],
      shelf: 'Salon',
      addedAt: DateTime(2026, 1, 1),
      status: ReadingStatus.reading,
      pageCount: 400,
      currentPage: 120,
      startedAt: DateTime(2026, 1, 2),
      readingLog: [
        ReadingLogEntry(at: DateTime(2026, 1, 2), page: 40),
        ReadingLogEntry(at: DateTime(2026, 1, 5), page: 120),
      ],
    );

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  test('silme + Geri Al: kitap aynı kimlikle ve günlüğüyle geri döner',
      () async {
    final repository = FakeBookRepository(initial: [seed()]);
    final controller = LibraryController(repository, onNotify: (_, __) {});
    await controller.loadBooks();

    // Sil: listeden düşer, depodan kalkar.
    final ok = await controller.deleteBook('b1', allowUndo: true);
    expect(ok, isTrue);
    expect(controller.books, isEmpty);
    expect(repository.store, isEmpty);

    // Geri Al: aynı kimlik, raf, okuma durumu ve günlük aynen döner.
    final restored = await controller.restoreLastDeleted();
    expect(restored, isTrue);
    expect(repository.store, hasLength(1));
    final book = repository.store.single;
    expect(book.id, 'b1');
    expect(book.title, 'Dune');
    expect(book.shelf, 'Salon');
    expect(book.status, ReadingStatus.reading);
    expect(book.currentPage, 120);
    expect(book.readingLog, hasLength(2));
    expect(book.readingLog.last.page, 120);
    expect(controller.books, hasLength(1));
  });

  test('Geri Al süresi bitmeden fotoğraf dosyası silinmez; süre dolunca silinir',
      () async {
    final tempRoot =
        await Directory.systemTemp.createTemp('undo_window_test');
    addTearDown(() async {
      if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
    });
    final store = CoverPhotoStore(baseDir: () async => tempRoot);
    final coversDir =
        Directory('${tempRoot.path}${Platform.pathSeparator}covers');
    await coversDir.create(recursive: true);
    final photo = File('${coversDir.path}${Platform.pathSeparator}c.jpg');
    await photo.writeAsBytes([1, 2, 3]);

    final repository = FakeBookRepository(initial: [
      BookModel(
        id: 'b1',
        title: 'Fotoğraflı',
        addedAt: DateTime(2026, 1, 1),
        coverPath: photo.path,
      ),
    ]);
    final controller = LibraryController(
      repository,
      onNotify: (_, __) {},
      coverStore: store,
      deleteUndoWindow: const Duration(milliseconds: 50),
    );
    await controller.loadBooks();

    // Sil: dosya geri alma şansı sürerken yerinde durur.
    await controller.deleteBook('b1', allowUndo: true);
    expect(photo.existsSync(), isTrue);

    // Geri Al: kitap geri döner, dosya hâlâ yerindedir.
    expect(await controller.restoreLastDeleted(), isTrue);
    expect(photo.existsSync(), isTrue);

    // İkinci silme: süre (50 ms) dolunca gerçek silme sonucu tamamlanır.
    await controller.deleteBook('b1', allowUndo: true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(photo.existsSync(), isFalse);
    // Süre doldu: artık geri koyulamaz.
    expect(await controller.restoreLastDeleted(), isFalse);
  });

  test('Geri koyulacak kayıt yoksa Geri Al false döner', () async {
    final repository = FakeBookRepository(initial: []);
    final controller = LibraryController(repository, onNotify: (_, __) {});
    await controller.loadBooks();

    expect(await controller.restoreLastDeleted(), isFalse);
  });

  testWidgets('detay sayfasından silme snackbar ve Geri Al düğmesi verir; '
      'dokununca kitap geri döner', (tester) async {
    final repository = FakeBookRepository(initial: [seed()]);
    final controller = Get.put<LibraryController>(
      // Varsayılan (7 sn) geri alma penceresiyle: widget testinin saati
      // pumpAndSettle ile ilerlediği için kısa pencere test içinde dolabilir;
      // zamanlayıcı "Geri Al" dokunuşuyla iptal edilir.
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );

    // Detay sayfası tek rotaysa silme sonrası AppNav.pop yapacak bir
    // liste sayfası gerekir: kökte basit bir sayfa kurup detayı üstüne
    // açıyoruz. (Get.to'nun geleceği rota kapanınca tamamlanır; await
    // edilmez — yoksa test gövdesi pop'ı sonsuza dek bekler.)
    await tester.pumpWidget(
      GetMaterialApp(home: Scaffold(appBar: AppBar(title: const Text('Liste')))),
    );
    await tester.pumpAndSettle();
    Get.to(() => const BookDetailPage(bookId: 'b1'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sil'));
    await tester.pumpAndSettle();

    // Onay diyaloğu; "Sil" yazısı şerit + diyalogta iki kez görünür.
    expect(find.text('Kitap silinsin mi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sil').last);
    await tester.pumpAndSettle();

    // Diyalog kapandı, detay sayfası da kapandı; snackbar listede durur.
    expect(find.text('Kitap silinsin mi?'), findsNothing);
    expect(find.text('Kitap silindi'), findsOneWidget);
    expect(find.textContaining('kitaplıktan silindi.'), findsOneWidget);
    expect(controller.books, isEmpty);

    // Geri Al: kitap aynı kimlikle geri koyulur; snackbar kapanır.
    await tester.tap(find.text('Geri Al'));
    await tester.pumpAndSettle();
    expect(controller.books.map((b) => b.id), ['b1']);
    expect(repository.store, hasLength(1));
    expect(find.text('Kitap silindi'), findsNothing);

    // Kalan snackbar/zamanlayıcılar bittikten sonra testi bitir.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  });
}

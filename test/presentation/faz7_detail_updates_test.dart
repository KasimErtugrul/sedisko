import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/reading_log_entry.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/pages/book_detail_page.dart';
import 'package:kitaplik/presentation/widgets/reading_stats_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keşke 32 + 33 (1.26.0): detay sayfasının iki rötuşu.
///
/// - Keşke 32: "237 yazmak yerine '+10' basmak benim için daha kolaydı" —
///   'Kaçıncı sayfadasın?' diyaloğunda hızlı adım düğmeleri.
/// - Keşke 33: "Kitabı okuyan biri için güzel; benim için aşağıda yer
///   kaplıyor" — okuma istatistikleri kartı katlanabilir; varsayılan KAPALI.
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
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  /// Okumaya başlanmış kitap: sayfa 237 / 300.
  BookModel readingBook({List<ReadingLogEntry> log = const []}) => BookModel(
        id: 'b1',
        title: 'Dune',
        pageCount: 300,
        status: ReadingStatus.reading,
        currentPage: 237,
        addedAt: DateTime(2026, 1, 1),
        startedAt: DateTime(2026, 6, 1),
        readingLog: log,
      );

  LibraryController putLibrary(BookModel book) {
    final library = Get.put<LibraryController>(
      LibraryController(
        FakeBookRepository(initial: [book]),
        onNotify: (_, __) {},
      ),
      permanent: true,
    );
    return library;
  }

  Future<void> pumpDetail(WidgetTester tester, {bool tall = true}) async {
    if (tall) {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      GetMaterialApp(home: const BookDetailPage(bookId: 'b1')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('keşke 32: +10 düğmesi alanı 10 artırır ve kaydeder',
      (tester) async {
    final library = putLibrary(readingBook());
    await pumpDetail(tester);

    // Okuma kartındaki 'Sayfayı güncelle' düğmesi diyaloğu açar.
    await tester.tap(find.text('Sayfayı güncelle'));
    await tester.pumpAndSettle();

    expect(find.text('Kaçıncı sayfadasın?'), findsOneWidget);
    expect(find.text('hızlı adım'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('page-step-10')));
    await tester.pumpAndSettle();

    // 237 + 10 = 247 — alan güncellendi (suffix '/ 300' aynı satırda).
    final dialogField = find.byType(TextField).first;
    final field =
        tester.widget<TextField>(dialogField).controller!;
    expect(field.text, '247');

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await drainSnackbars(tester);

    expect(library.books.single.currentPage, 247);
  });

  testWidgets('keşke 32: +1 ve −1 adımları çalışır', (tester) async {
    putLibrary(readingBook());
    await pumpDetail(tester);

    await tester.tap(find.text('Sayfayı güncelle'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('page-step-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('page-step-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('page-step--1')));
    await tester.pumpAndSettle();

    final field =
        tester.widget<TextField>(find.byType(TextField).first).controller!;
    expect(field.text, '238');
  });

  testWidgets('keşke 32: toplam sayfayı aşan adım kırpılır', (tester) async {
    putLibrary(readingBook());
    await pumpDetail(tester);

    await tester.tap(find.text('Sayfayı güncelle'));
    await tester.pumpAndSettle();

    // 237 + 10 + 10 + ... toplam 300'ü aşamaz.
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byKey(const ValueKey('page-step-10')));
      await tester.pumpAndSettle();
    }
    final field =
        tester.widget<TextField>(find.byType(TextField).first).controller!;
    expect(field.text, '300');
  });

  testWidgets('keşke 33: istatistik kartı varsayılan KAPALI açılır',
      (tester) async {
    putLibrary(readingBook(log: [
      ReadingLogEntry(
        at: DateTime(2026, 11, 18, 14),
        page: 200,
      ),
      ReadingLogEntry(
        at: DateTime(2026, 11, 19, 15),
        page: 237,
      ),
    ]));
    await pumpDetail(tester);

    // Başlık görünür; içerik katlıdır.
    expect(find.text('Okuma İstatistikleri'), findsOneWidget);
    expect(find.byKey(const ValueKey('stats-tile')), findsOneWidget);
    expect(find.text('Okunan sayfa'), findsNothing);

    await tester.tap(find.text('Okuma İstatistikleri'));
    await tester.pumpAndSettle();

    // Açınca kutular, grafik ve son kayıtlar kurulur.
    expect(find.text('Okunan sayfa'), findsOneWidget);
    expect(find.text('Son kayıtlar'), findsOneWidget);
  });

  testWidgets('keşke 33: panel tek başına da katlanır', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReadingStatsPanel(
            book: readingBook(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Okuma İstatistikleri'), findsOneWidget);
    expect(find.text('Okunan sayfa'), findsNothing);
  });
}

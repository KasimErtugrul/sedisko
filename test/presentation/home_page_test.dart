import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/pages/home_page.dart';

/// Bellek içi sahte repository; kitaplar doğrudan store ile beslenir.
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

BookModel seed(String id, String title, String shelf) => BookModel(
      id: id,
      title: title,
      shelf: shelf,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  late FakeBookRepository repository;

  setUp(() {
    Get.testMode = true;
    repository = FakeBookRepository(initial: [
      seed('b1', 'Denizler Altında', 'Roman'),
      seed('b2', 'Kürk Mantolu Madonna', 'Roman'),
      seed('b3', 'Osmanlı Tarihi', 'Tarih'),
      seed('b4', 'Not Defteri', ''),
    ]);
    Get.put(LibraryController(repository, onNotify: (_, __) {}));
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
  }

  testWidgets('raf başlıkları kitap sayısıyla görünür', (tester) async {
    await pumpHome(tester);

    // Başlık ve raf çipi aynı etiketi taşır: 2 eşleşme.
    expect(find.text('Roman (2)'), findsNWidgets(2));
    expect(find.text('Tarih (1)'), findsNWidgets(2));
    expect(find.text('Denizler Altında'), findsOneWidget);

    // 'Rafsız' bölümü listenin sonundadır; builder tembel olduğu için
    // görünmeyen bölüm kurulmaz, önce kaydır.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('shelf-Rafsız')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Rafsız (1)'), findsNWidgets(2));
    expect(find.text('Not Defteri'), findsOneWidget);
  });

  testWidgets('raf başlığına dokununca bölüm katlanır', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey('shelf-Roman')));
    await tester.pumpAndSettle();

    // Katlanmış bölümün kitapları listeden kalkar, başlık kalır.
    expect(find.text('Denizler Altında'), findsNothing);
    expect(find.text('Kürk Mantolu Madonna'), findsNothing);
    expect(find.byKey(const ValueKey('shelf-Roman')), findsOneWidget);
    // Diğer raflar etkilenmez.
    expect(find.text('Osmanlı Tarihi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shelf-Roman')));
    await tester.pumpAndSettle();

    expect(find.text('Denizler Altında'), findsOneWidget);
    expect(find.text('Kürk Mantolu Madonna'), findsOneWidget);
  });

  testWidgets('raf çipi yalnız o raftaki kitapları gösterir', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tarih (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Osmanlı Tarihi'), findsOneWidget);
    expect(find.text('Denizler Altında'), findsNothing);
    expect(find.text('Not Defteri'), findsNothing);
    expect(find.byKey(const ValueKey('shelf-Tarih')), findsOneWidget);
    expect(find.byKey(const ValueKey('shelf-Roman')), findsNothing);
  });

  testWidgets("'Tümü' çipi raf filtresini temizler", (tester) async {
    await pumpHome(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Rafsız (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Denizler Altında'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tümü'));
    await tester.pumpAndSettle();

    expect(find.text('Denizler Altında'), findsOneWidget);
    // 'Rafsız' bölümü listenin sonunda; ekranda değilse kaydırarak doğrula.
    await tester.scrollUntilVisible(
      find.text('Not Defteri'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Not Defteri'), findsOneWidget);
  });

  testWidgets("'Raflar' sayfası rafa atlar", (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byTooltip('Raflar'));
    await tester.pumpAndSettle();

    expect(find.text('Tüm raflar'), findsOneWidget);
    expect(find.text('Roman'), findsOneWidget);
    expect(find.text('2 kitap'), findsOneWidget);

    await tester.tap(find.text('Roman'));
    await tester.pumpAndSettle();

    expect(find.text('Osmanlı Tarihi'), findsNothing);
    expect(find.text('Denizler Altında'), findsOneWidget);
    expect(find.byKey(const ValueKey('shelf-Roman')), findsOneWidget);
  });

  testWidgets('arama alanı yazınca raf çipleri de filtrede kalır',
      (tester) async {
    await pumpHome(tester);

    await tester.enterText(find.byType(TextField).first, 'madonna');
    await tester.pumpAndSettle();

    expect(find.text('Kürk Mantolu Madonna'), findsOneWidget);
    expect(find.text('Denizler Altında'), findsNothing);
    expect(find.text('Osmanlı Tarihi'), findsNothing);
  });
}

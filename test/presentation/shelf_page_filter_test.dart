import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raf sayfası: yazar filtresi (genel filtreleme) ve "rafa topla" akışı.
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

BookModel seed(
  String id,
  String title, {
  required String author,
  required String shelf,
}) =>
    BookModel(
      id: id,
      title: title,
      authors: [author],
      shelf: shelf,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  late FakeBookRepository repository;
  late LibraryController controller;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      seed('b1', 'Benim Adım Kırmızı', author: 'Orhan Pamuk', shelf: 'Roman'),
      seed('b2', 'Simyacı', author: 'Orhan Pamuk', shelf: 'Tarih'),
      seed('b3', 'Dönüşüm', author: 'Franz Kafka', shelf: 'Roman'),
    ]);
    controller = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await controller.loadBooks();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Snackbar'ın 3 sn'lik otomatik kapanma zamanlayıcısını sahte saatte
  /// tüketir. Tüketilmezse test sonunda "Timer is still pending" hatası
  /// çıkar ve GetX snack kuyruğu sonraki testleri bloklar.
  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  /// Raflar sekmesinden 'Tüm kitaplar' sayfasını açar.
  Future<void> openAllBooks(WidgetTester tester) async {
    await tester.tap(find.text('Raflar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-card-all')));
    await tester.pumpAndSettle();
  }

  /// Açık filtre sayfasından [author] yazarını seçer.
  Future<void> pickAuthor(WidgetTester tester, String author) async {
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text(author),
      ),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('yazar filtresi başlığı, çipi ve listeyi günceller',
      (tester) async {
    await pumpApp(tester);
    await openAllBooks(tester);

    // Başlangıç: tüm kitaplar.
    expect(find.text('Dönüşüm'), findsOneWidget);

    await pickAuthor(tester, 'Orhan Pamuk');

    // Başlık yazar adını alır; çip filtrelenmiş yazarı gösterir.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Orhan Pamuk')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    // Yalnız seçilen yazarın kitapları kalır.
    expect(find.text('Benim Adım Kırmızı'), findsOneWidget);
    expect(find.text('Simyacı'), findsOneWidget);
    expect(find.text('Dönüşüm'), findsNothing);
  });

  testWidgets('çipten filtre temizlenince tüm kitaplar geri gelir',
      (tester) async {
    await pumpApp(tester);
    await openAllBooks(tester);
    await pickAuthor(tester, 'Orhan Pamuk');
    expect(find.text('Dönüşüm'), findsNothing);

    // Chip'in varsayılan sil ikonu Icons.cancel'dır (Icons.close değil).
    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pumpAndSettle();

    expect(find.text('Dönüşüm'), findsOneWidget);
    expect(controller.authorFilter.value, isNull);
  });

  testWidgets("'Rafa topla' aynı yazarın kitaplarını yeni rafa taşır",
      (tester) async {
    await pumpApp(tester);
    await openAllBooks(tester);
    await pickAuthor(tester, 'Orhan Pamuk');

    await tester.tap(find.byIcon(Icons.folder_special_outlined));
    await tester.pumpAndSettle();

    // Raf seçicide 'Yeni raf...' ile hedef oluştur.
    await tester.tap(find.text('Yeni raf...'));
    await tester.pumpAndSettle();
    // Alan diyaloğun içindeki TextField'dır (ana sayfadaki arama alanı
    // IndexedStack'te offstage beklediği için doğrudan byType kullanılmaz).
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Yazar Rafı',
    );
    await tester.tap(find.text('Oluştur'));
    await tester.pumpAndSettle();

    // Bilgi balonu + iki kitap da aynı rafda.
    expect(
      find.text('2 kitap "Yazar Rafı" rafına toplandı.'),
      findsOneWidget,
    );
    expect(controller.byId('b1')!.shelf, 'Yazar Rafı');
    expect(controller.byId('b2')!.shelf, 'Yazar Rafı');
    // Kafka'nın kitabı taşınmaz.
    expect(controller.byId('b3')!.shelf, 'Roman');
    expect(
      repository.store.firstWhere((b) => b.id == 'b1').shelf,
      'Yazar Rafı',
    );
    await drainSnackbars(tester);
  });

  testWidgets('yazara dokunulan raf sayfasında toplama sonrası geri döner',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Raflar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-card-Roman')));
    await tester.pumpAndSettle();

    // 'Roman' rafında iki yazar var; yazar filtresiyle daralt.
    expect(find.text('Benim Adım Kırmızı'), findsOneWidget);
    expect(find.text('Dönüşüm'), findsOneWidget);
    await pickAuthor(tester, 'Orhan Pamuk');
    expect(find.text('Benim Adım Kırmızı'), findsOneWidget);
    expect(find.text('Dönüşüm'), findsNothing);

    // Orhan Pamuk'un kitabını 'Tarih' rafına topla.
    await tester.tap(find.byIcon(Icons.folder_special_outlined));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(ListTile), matching: find.text('Tarih')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('1 kitap "Tarih" rafına toplandı.'),
      findsOneWidget,
    );
    expect(controller.byId('b1')!.shelf, 'Tarih');

    // Raf spesifik sayfada toplama sonrası raf kartlarına dönülür.
    expect(find.byKey(const ValueKey('shelf-card-all')), findsOneWidget);
    expect(controller.authorFilter.value, isNull);
    await drainSnackbars(tester);
  });

  testWidgets('uzun basınca kitap tek tek rafa taşınır', (tester) async {
    await pumpApp(tester);
    await openAllBooks(tester);

    await tester.longPress(find.text('Simyacı'));
    await tester.pumpAndSettle();

    expect(find.text('Kitabı hangi rafa taşımak istersin?'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(ListTile), matching: find.text('Rafsız')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Taşındı'), findsOneWidget);
    expect(controller.byId('b2')!.shelf, '');
    await drainSnackbars(tester);
  });
}

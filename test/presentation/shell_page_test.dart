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
  late SharedPreferences prefs;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      seed('b1', 'Denizler Altında', 'Roman'),
      seed('b2', 'Kürk Mantolu Madonna', 'Roman'),
      seed('b3', 'Osmanlı Tarihi', 'Tarih'),
      seed('b4', 'Not Defteri', ''),
    ]);
    final controller = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await controller.loadBooks();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('alt navigasyon Ana Sayfa, Raflar ve Ayarlar sekmelerini gösterir',
      (tester) async {
    await pumpShell(tester);

    // Üç sekme etiketi görünür (IndexedStack'te kapalı sayfaların AppBar
    // başlıkları hit-test edilemez; hitTestable yalnız etiketleri bulur).
    expect(find.text('Ana Sayfa').hitTestable(), findsOneWidget);
    expect(find.text('Raflar').hitTestable(), findsOneWidget);
    expect(find.text('Ayarlar').hitTestable(), findsOneWidget);

    // Ana Sayfa açılışta seçilidir: özet + bölüm şeritleri ("Tüm kitaplar"
    // listesi ana sayfadan kaldırıldı; tam kitaplık Raflar sekmesindeki
    // "Tüm kitaplar" kartından açılır).
    expect(find.text('Toplam'), findsOneWidget);
    expect(find.text('Okunuyor'), findsOneWidget);
    expect(find.text('Bitti'), findsOneWidget);
    expect(find.text('Favoriler'), findsWidgets);

    // Ayarlar sekmesi kapalıyken içerik görünür değil (IndexedStack offstage).
    expect(find.text('Görünüm').hitTestable(), findsNothing);

    await tester.tap(find.text('Ayarlar').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Görünüm').hitTestable(), findsOneWidget);
    expect(
      find.text('Uygulama içi özellikler').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('Raflar sekmesinde yatay raf kartları vardır', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Raflar').hitTestable());
    await tester.pumpAndSettle();

    // Raflar sekmesi: 'Tüm kitaplar' ve raflar, ad + kitap sayısı kartları.
    expect(find.byKey(const ValueKey('shelf-card-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('shelf-card-Roman')), findsOneWidget);
    expect(find.byKey(const ValueKey('shelf-card-Rafsız')), findsOneWidget);
    expect(find.text('2 kitap'), findsOneWidget); // Roman kartı
  });

  testWidgets('raf kartına dokununca rafın kitapları yeni sayfada açılır',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Raflar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-card-Roman')));
    await tester.pumpAndSettle();

    // AppBar başlığı raf adıdır; yalnız Roman kitapları listelenir.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Roman')),
      findsOneWidget,
    );
    expect(find.text('Denizler Altında'), findsOneWidget);
    expect(find.text('Kürk Mantolu Madonna'), findsOneWidget);
    expect(find.text('Osmanlı Tarihi'), findsNothing);
    expect(find.text('Not Defteri'), findsNothing);
  });

  testWidgets("'Tüm kitaplar' kartı kitaplığın tamamını listeler",
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Raflar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-card-all')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Tüm kitaplar'),
      ),
      findsOneWidget,
    );
    expect(find.text('Denizler Altında'), findsOneWidget);
    expect(find.text('Kürk Mantolu Madonna'), findsOneWidget);

    // ListView tembel yapıdadır; 'Rafsız' kitap için kaydır.
    await tester.scrollUntilVisible(
      find.text('Not Defteri'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Not Defteri'), findsOneWidget);
  });

  testWidgets('ana sayfada arama yazınca sonuç listesi ve durum çipleri çıkar',
      (tester) async {
    await pumpShell(tester);

    await tester.enterText(find.byType(TextField).first, 'madonna');
    await tester.pumpAndSettle();

    expect(find.text('Kürk Mantolu Madonna'), findsOneWidget);
    expect(find.text('Denizler Altında'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Hepsi'), findsOneWidget);
  });

  testWidgets('Karanlık teması seçilince tercih kalıcı yazılır', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Ayarlar').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Karanlık'));
    await tester.pumpAndSettle();

    final settings = Get.find<SettingsController>();
    expect(settings.themeMode.value, ThemeMode.dark);
    expect(
      prefs.getInt('settings_theme_mode'),
      ThemeMode.dark.index,
    );
  });

  testWidgets('Kapak görselleri anahtarı tercihi değiştirir', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Ayarlar').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kapak görselleri'));
    await tester.pumpAndSettle();

    expect(Get.find<SettingsController>().showCovers.value, isFalse);
    expect(prefs.getBool('settings_show_covers'), isFalse);
  });
}

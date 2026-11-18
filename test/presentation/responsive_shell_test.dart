import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/shell_page.dart';
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

/// Kabuğun responsive davranışı: dar ekranda alt NavigationBar, geniş
/// ekranda (600 dp+) sol NavigationRail. İki gösterim de aynı sekmeleri
/// sunar ve IndexedStack durumunu korur.
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
      BookModel(
        id: 'b1',
        title: 'Simyacı',
        shelf: 'Roman',
        addedAt: DateTime(2026, 1, 1),
      ),
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

  Future<void> pumpShell(
    WidgetTester tester, {
    required double width,
    required double height,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dar ekranda alt bar vardır, rail yoktur', (tester) async {
    await pumpShell(tester, width: 400, height: 2000);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('geniş ekranda rail vardır, alt bar yoktur', (tester) async {
    await pumpShell(tester, width: 800, height: 2000);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    // Rail dört hedefi de etiketle gösterir.
    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Raflar'), findsOneWidget);
    expect(find.text('Yazarlar'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
  });

  testWidgets('rail hedefi dokunulunca sekme değişir', (tester) async {
    await pumpShell(tester, width: 800, height: 2000);

    // Rail etiketi üzerinden Yazarlar sekmesine geç.
    final rail = find.byType(NavigationRail);
    await tester.tap(
      find.descendant(of: rail, matching: find.text('Yazarlar')),
    );
    await tester.pumpAndSettle();

    // Yazarlar sayfası AppBar'ı görünür: sekme değişmiştir.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Yazarlar'))
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('rail ile gezinince IndexedStack durumu korunur',
      (tester) async {
    await pumpShell(tester, width: 800, height: 2000);

    // Ana sayfa aramasına yaz; sekmeler arasında gezip geri dönünce
    // alan aynı içeriği korumalı (IndexedStack).
    await tester.enterText(find.byType(TextField).first, 'simy');
    final rail = find.byType(NavigationRail);
    await tester.tap(
      find.descendant(of: rail, matching: find.text('Ayarlar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: rail, matching: find.text('Ana Sayfa')),
    );
    await tester.pumpAndSettle();

    expect(find.text('simy'), findsOneWidget);
  });

  testWidgets('ShellPage doğrudan pompalanınca da kırılım çalışır',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: ShellPage()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}

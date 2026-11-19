import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/shelf_organize_controller.dart';
import 'package:kitaplik/presentation/pages/home_page.dart';
import 'package:kitaplik/presentation/widgets/home/favorite_author_strip.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ana sayfadaki "Favori yazarlar" bölümü (1.16.0, kullanıcı isteği):
/// "ana sayfada da favoriye alınmış yazarları görmek istiyoruz."
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

BookModel book(String id, String title, List<String> authors) => BookModel(
      id: id,
      title: title,
      authors: authors,
      shelf: 'Raf',
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  late FakeBookRepository repository;
  late ShelfOrganizeController organize;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      book('b1', 'Simyacı', ['Paulo Coelho']),
      book('b2', 'Beyaz Kale', ['Orhan Pamuk']),
      book('b3', 'Kar', ['Orhan Pamuk']),
    ]);
    final library = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await library.loadBooks();
    Get.put<ShelfOrganizeController>(
      ShelfOrganizeController(shelfStore: ShelfLocalDataSource(prefs)),
      permanent: true,
    );
    organize = Get.find<ShelfOrganizeController>();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpHome(WidgetTester tester, {double height = 4000}) async {
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(home: const HomePage()));
    await tester.pumpAndSettle();
  }

  testWidgets('favori yazarlar bölümünde yıldız kartları görünür',
      (tester) async {
    await organize.addFavoriteAuthor('Orhan Pamuk');
    await pumpHome(tester);

    expect(find.text('Favori yazarlar'), findsOneWidget);
    final strip = find.byType(FavoriteAuthorStrip);
    expect(
      find.descendant(of: strip, matching: find.text('Orhan Pamuk')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('2 kitap')),
      findsOneWidget,
    );
    // Favori olmayan yazar şeritte yok.
    expect(
      find.descendant(of: strip, matching: find.text('Paulo Coelho')),
      findsNothing,
    );
  });

  testWidgets('favori yazar kartına dokununca yazarın kitapları açılır',
      (tester) async {
    await organize.addFavoriteAuthor('Orhan Pamuk');
    tester.view.physicalSize = const Size(400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const HomePage()),
          GetPage(
            name: '/shelf',
            page: () => const Scaffold(body: SizedBox()),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const ValueKey('home-favorite-author-orhan pamuk')));
    await tester.pumpAndSettle();

    // Kart bir rotaya dokunulabilir: rota yığını değişti (pop edilebilir).
    expect(Get.key.currentState!.canPop(), isTrue);
  });

  testWidgets('kitabı olmayan favori yazar "Kitaplıkta yok" yazar',
      (tester) async {
    await organize.addFavoriteAuthor('Bilinmeyen Yazar');
    await pumpHome(tester);

    final strip = find.byType(FavoriteAuthorStrip);
    expect(
      find.descendant(of: strip, matching: find.text('Bilinmeyen Yazar')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('Kitaplıkta yok')),
      findsOneWidget,
    );
  });

  testWidgets('favori seçilmediyse ipucu kartı yer tutar', (tester) async {
    await pumpHome(tester);

    expect(find.text('Favori yazarlar'), findsOneWidget);
    expect(
      find.textContaining('Henüz favori yazar seçmedin'),
      findsOneWidget,
    );
    expect(find.byType(FavoriteAuthorStrip), findsNothing);
  });
}

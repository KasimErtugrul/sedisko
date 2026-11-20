import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:kitaplik/data/datasources/open_library_remote_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/authors_page.dart';
import 'package:kitaplik/presentation/pages/settings_page.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:kitaplik/presentation/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keşke 18, 20, 6, 2 (1.26.0): bulmak ve yönlendirilmek.
///
/// - Keşke 18: Yazarlar sayfası kendi arama kutusunu taşır ("yazar sayısı
///   artınca kaydırarak aramak eziyet oldu").
/// - Keşke 20: ana sayfa araması kaç kitap bulduğunu yazar ("aramanın
///   bittiğini yazarak anlıyorum, sayı görmeden").
/// - Keşke 6: ekle menüsünün internet yolu adında 'İnternette' der ve arama
///   sayfası nerede olduğunu söyler ("İkisi de 'ara' dediği için önce
///   kitabın adını üstteki kutuya yazdım; 'yok' dedi").
/// - Keşke 2: 'Uygulama nasıl kullanılır?' sayfası ve girişleri.
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
  required List<String> authors,
  String shelf = '',
}) =>
    BookModel(
      id: id,
      title: title,
      authors: authors,
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
      seed('b1', 'Simyacı', authors: ['Orhan Pamuk']),
      seed('b2', 'Benim Adım Kırmızı', authors: ['Orhan Pamuk']),
      seed('b3', 'Kürk Mantolu Madonna', authors: ['Sabahattin Ali']),
      seed('b4', 'Sinekli Bakkal', authors: ['Halide Edib'], shelf: 'Roman'),
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

  testWidgets('keşke 18: yazar araması katlanarak süzer', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const AuthorsPage()),
    );
    await tester.pumpAndSettle();

    // Boş sorguda bütün yazarlar durur (iki Orhan Pamuk kartı tek karta
    // katlanır: 'Orhan Pamuk' + 'Sabahattin Ali' + 'Halide Edib').
    expect(find.text('Orhan Pamuk'), findsOneWidget);
    expect(find.text('Sabahattin Ali'), findsOneWidget);
    expect(find.text('Halide Edib'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('authors-search-field')),
      'pamuk',
    );
    await tester.pumpAndSettle();

    expect(find.text('Orhan Pamuk'), findsOneWidget);
    expect(find.text('Sabahattin Ali'), findsNothing);
    expect(find.text('Halide Edib'), findsNothing);
  });

  testWidgets('keşke 18: aramaya uyan yazar yoksa dürüst boşluk', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const AuthorsPage()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('authors-search-field')),
      'dostoyevski',
    );
    await tester.pumpAndSettle();

    expect(find.text('Aramana uyan yazar yok.'), findsOneWidget);
    expect(find.text('Orhan Pamuk'), findsNothing);
  });

  testWidgets('keşke 18: temizle düğmesi listeyi geri getirir', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const AuthorsPage()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('authors-search-field')),
      'pamuk',
    );
    await tester.pumpAndSettle();
    expect(find.text('Sabahattin Ali'), findsNothing);

    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Sabahattin Ali'), findsOneWidget);
  });

  testWidgets('keşke 20: arama yazılınca sonuç sayısı yazar', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('search-result-count')), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'orhan');
    await tester.pumpAndSettle();

    // 'orhan' yazar alanında iki kitaba uyar.
    expect(find.text('2 kitap bulundu'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'simyacı');
    await tester.pumpAndSettle();
    expect(find.text('1 kitap bulundu'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'yok böyle kitap');
    await tester.pumpAndSettle();
    // Boş sonuçta sayı yerine aramanın bittiği söylenir.
    expect(find.text('Arama bitti.'), findsOneWidget);
  });

  testWidgets('keşke 6: arama sayfası nerede olduğunu söyler', (tester) async {
    // Arama sayfasının rota bağlamı uzak veri kaynağını ister.
    Get.put<OpenLibraryRemoteDataSource>(
      OpenLibraryRemoteDataSource(http.Client()),
      permanent: true,
    );
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.search,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Bu arama internette (Open Library) yapılır'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Kendi kitaplarını ana sayfanın üstündeki'),
      findsOneWidget,
    );
  });

  testWidgets('keşke 2: yardım sayfası yol yol açılır', (tester) async {
    // Dokuz bölüm tek ekrana sığmaz; ListView tembel kurar. Yüksek yüzey:
    // bütün başlıklar ağaçta kurulsun.
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.help,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uygulama nasıl kullanılır?'), findsOneWidget);
    expect(find.text('İlk kitabını ekle'), findsOneWidget);
    expect(find.text('Raflarını hazırla'), findsOneWidget);
    expect(find.text('Bir terslik olursa'), findsOneWidget);

    // Bölüm kapalıdır; dokunınca paragraflar açılır.
    expect(find.textContaining('Barkod tara — kitabın arkasındaki'),
        findsNothing);
    await tester.tap(find.text('İlk kitabını ekle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Barkod tara — kitabın arkasındaki'),
        findsOneWidget);
  });

  testWidgets('keşke 2: Ayarlar satırı yardım sayfasını açar', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        getPages: AppPages.pages,
        home: const SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uygulama nasıl kullanılır?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-help-tile')));
    await tester.pumpAndSettle();

    expect(find.text('İlk kitabını ekle'), findsOneWidget);
  });

  testWidgets('keşke 2: boş kitaplıkta Nasıl kullanılır? düğmesi yardım açar',
      (tester) async {
    // Boş kitaplık: seedsiz depo + yeniden yükleme.
    repository.store.clear();
    await controller.loadBooks();

    await tester.pumpWidget(
      GetMaterialApp(
        getPages: AppPages.pages,
        home: Scaffold(
          body: HomePage(
            onOpenShelves: null,
            onOpenAuthors: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Boş kitaplıkta HomeEmptyState kurulur; ikinci yol yardım sayfasıdır
    // (keşke 2). Dokunuş rota üzerinden açar.
    expect(find.byKey(const ValueKey('empty-open-help')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('empty-open-help')));
    await tester.pumpAndSettle();

    expect(find.text('İlk kitabını ekle'), findsOneWidget);
  });
}

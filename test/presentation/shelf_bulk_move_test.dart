import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/shelf_organize_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:kitaplik/presentation/routes/route_args.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rafın TÜM kitaplarını başka rafa toplu taşıma (1.16.0, kullanıcı
/// isteği): "ben mesela a rafındaki tüm kitapları b rafına
/// aktarabiliyormuyum... yoksa da bu özellik çok iyi olurdu."
///
/// Kapasite denetimi 1.15.0 kalınlık modeliyle uyumludur: kalınlık hesabı
/// sayfa sayısından yer hesaplanır (bilinmeyen sayfa = 2,5 cm),
/// taşan plan taşarsa kullanıcıya hesabıyla sorulur.
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

BookModel shelfBook(String id, String shelf) => BookModel(
      id: id,
      title: 'Kitap $id',
      shelf: shelf,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  late FakeBookRepository repository;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      shelfBook('a1', 'A'),
      shelfBook('a2', 'A'),
      shelfBook('a3', 'A'),
      shelfBook('b1', 'B'),
    ]);
    final library = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await library.loadBooks();
    final organize = Get.put<ShelfOrganizeController>(
      ShelfOrganizeController(shelfStore: ShelfLocalDataSource(prefs)),
      permanent: true,
    );
    await organize.addShelf(name: 'A', lengthCm: 25); // 10 kitap ≈ 25 cm
    await organize.addShelf(name: 'B', lengthCm: 13); // 5 kitap ≈ 13 cm
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpShelfPage(WidgetTester tester, String? shelf) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
    Get.toNamed(Routes.shelf, arguments: ShelfArgs(shelf: shelf));
    await tester.pumpAndSettle();
  }

  testWidgets("A rafındaki tüm kitaplar B rafına tek hamlede taşınır",
      (tester) async {
    await pumpShelfPage(tester, 'A');

    await tester.tap(find.byKey(const ValueKey('shelf-bulk-move')));
    await tester.pumpAndSettle();

    // Raf seçici: hedef B.
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    // Yer yeter (3 kitap × 1 birim + mevcut 1 = 4 ≤ 5): soru sormadan taşınır.
    expect(find.text('Hedef raf taşacak'), findsNothing);
    expect(find.text('3 kitap "B" rafına toplandı.'), findsOneWidget);

    final library = Get.find<LibraryController>();
    expect(library.shelfCount('A'), 0);
    expect(library.shelfCount('B'), 4);
    // Kaynak raf tamamen boşaldı: raf sayfasından dönüldü.
    expect(find.text('A'), findsNothing);

    // Bildirim zamanlayıcısını bitir (test sonunda asılı timer kalmasın).
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('hedef raf taşarsa hesap gösterilir, vazgeçilebilir',
      (tester) async {
    final organize = Get.find<ShelfOrganizeController>();
    await organize.updateShelf(
      id: organize.shelves.firstWhere((s) => s.name == 'B').id,
      name: 'B',
      lengthCm: 5, // 1 mevcut kitap var: kalan 2,5 cm; gelen 7,5 cm
    );

    await pumpShelfPage(tester, 'A');

    await tester.tap(find.byKey(const ValueKey('shelf-bulk-move')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(find.text('Hedef raf taşacak'), findsOneWidget);
    expect(find.textContaining('yer kaplıyor'), findsOneWidget);

    // Vazgeç: hiçbir kitap taşınmaz.
    await tester.tap(find.byKey(const ValueKey('bulk-move-cancel')));
    await tester.pumpAndSettle();

    final library = Get.find<LibraryController>();
    expect(library.shelfCount('A'), 3);
    expect(library.shelfCount('B'), 1);
    expect(find.text('Kitap a1'), findsOneWidget); // sayfa hâlâ açık
  });

  testWidgets('taşma uyarısında "Yine de taşı" onaylanırsa taşınır',
      (tester) async {
    final organize = Get.find<ShelfOrganizeController>();
    await organize.updateShelf(
      id: organize.shelves.firstWhere((s) => s.name == 'B').id,
      name: 'B',
      lengthCm: 5,
    );

    await pumpShelfPage(tester, 'A');

    await tester.tap(find.byKey(const ValueKey('shelf-bulk-move')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bulk-move-confirm')));
    await tester.pumpAndSettle();

    final library = Get.find<LibraryController>();
    expect(library.shelfCount('A'), 0);
    expect(library.shelfCount('B'), 4);

    // Bildirim zamanlayıcısını bitir (test sonunda asılı timer kalmasın).
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets("'Tüm kitaplar' görünümünde toplu taşıma aksiyonu yoktur",
      (tester) async {
    await pumpShelfPage(tester, null);

    expect(find.byKey(const ValueKey('shelf-bulk-move')), findsNothing);
  });
}

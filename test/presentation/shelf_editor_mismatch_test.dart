import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/shelf_organize_controller.dart';
import 'package:kitaplik/presentation/pages/organize_setup_page.dart';
import 'package:kitaplik/presentation/pages/shelf_editor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.19.3: raf ataması ad bazlıdır; tanım adları kitaplardaki adlarla
/// birebir aynı değilse düzenleyicide uyarı kartı çıkar ve raf
/// diyaloğu kitaplardaki gerçek adları öneri çipi olarak sunar.
/// Kullanıcı vakası: kitaplar 'Koridor Raf 1' adındayken tanım
/// 'Koridor 1' açılmıştı; yalnız 'Tv uzeri' ≡ 'Tv Üzeri' katlaması
/// eşleştiği için tek kart dolu görünüyordu.
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

BookModel _book(String id, String shelf) => BookModel(
      id: id,
      title: 'Kitap $id',
      shelf: shelf,
      addedAt: DateTime(2026, 1, 1),
    );

ShelfModel _shelf(String id, String name, int cm, int order) =>
    ShelfModel(id: id, name: name, lengthCm: cm, order: order);

/// Kullanıcının ekran görüntüsündeki durumun küçük benzeri: kitaplar
/// 'Koridor Raf 1' / 'Tv Üzeri' adlarında; tanımlar 'Koridor 1' /
/// 'Tv uzeri' yazılmış. Katlama yalnız Tv çiftini eşleştirir.
Future<void> putHarness({
  required List<BookModel> books,
  required List<ShelfModel> shelves,
}) async {
  Get.testMode = true;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put<SettingsController>(
    SettingsController(prefs: prefs),
    permanent: true,
  );
  final shelfStore = ShelfLocalDataSource(prefs);
  if (shelves.isNotEmpty) {
    await shelfStore.saveShelves(shelves);
  }
  final library = Get.put<LibraryController>(
    LibraryController(FakeBookRepository(initial: books), onNotify: (_, __) {}),
    permanent: true,
  );
  await library.loadBooks();
  Get.put<ShelfOrganizeController>(
    ShelfOrganizeController(shelfStore: shelfStore),
    permanent: true,
  );
}

List<BookModel> mismatchBooks() => [
      _book('k1', 'Koridor Raf 1'),
      _book('k2', 'Koridor Raf 1'),
      _book('t1', 'Tv Üzeri'),
    ];

List<ShelfModel> shorthandShelves() => [
      _shelf('sh-kor', 'Koridor 1', 113, 0),
      _shelf('sh-tv', 'Tv uzeri', 75, 1),
    ];

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GetMaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  group('raf düzenleyici eşleşme uyarısı', () {
    testWidgets('tanımı olmayan kitap raf adları uyarı kartında listelenir',
        (tester) async {
      await putHarness(books: mismatchBooks(), shelves: shorthandShelves());
      await pumpPage(tester, const ShelfEditorPage());

      expect(
        find.byKey(const ValueKey('shelf-editor-mismatch-banner')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'tanım yok: Koridor Raf 1.',
        ),
        findsOneWidget,
      );
      // Katlama eşleşen 'Tv Üzeri' uyarı listesinde YOK.
      expect(find.textContaining('tanım yok: Tv Üzeri'), findsNothing);
    });

    testWidgets('diyaloğun öneri çipi tanım adını kitap adına çeker; '
        'uyarı kapanır', (tester) async {
      await putHarness(books: mismatchBooks(), shelves: shorthandShelves());
      await pumpPage(tester, const ShelfEditorPage());

      await tester.tap(find.byKey(const ValueKey('shelf-editor-add')));
      await tester.pumpAndSettle();

      const chipKey = ValueKey('shelf-name-suggest-Koridor Raf 1');
      expect(find.byKey(chipKey), findsOneWidget);
      await tester.tap(find.byKey(chipKey));
      await tester.pump();

      final nameField =
          tester.widget<TextField>(find.byType(TextField).first);
      expect(nameField.controller!.text, 'Koridor Raf 1');

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      // Tanım artık kitabın gerçek adıyla eşleşiyor: uyarı kapanır.
      expect(
        find.byKey(const ValueKey('shelf-editor-mismatch-banner')),
        findsNothing,
      );
      expect(find.text('Koridor Raf 1'), findsWidgets);
    });

    testWidgets('her şey eşleştiğinde uyarı kartı çıkmaz', (tester) async {
      await putHarness(
        books: [_book('s1', 'Salon')],
        shelves: [_shelf('sh-1', 'Salon', 100, 0)],
      );
      await pumpPage(tester, const ShelfEditorPage());

      expect(
        find.byKey(const ValueKey('shelf-editor-mismatch-banner')),
        findsNothing,
      );
    });
  });

  group('kurulum sayfası eşleşme uyarısı', () {
    testWidgets('hazırlık kartında eşleşmeyen adlar uyarılır', (tester) async {
      await putHarness(books: mismatchBooks(), shelves: shorthandShelves());
      await pumpPage(tester, const OrganizeSetupPage());

      expect(
        find.byKey(const ValueKey('organize-mismatch-warning')),
        findsOneWidget,
      );
    });

    testWidgets('eşleşme tamamsa uyarı satırı yer tutmaz', (tester) async {
      await putHarness(
        books: [_book('s1', 'Salon')],
        shelves: [_shelf('sh-1', 'Salon', 100, 0)],
      );
      await pumpPage(tester, const OrganizeSetupPage());

      expect(
        find.byKey(const ValueKey('organize-mismatch-warning')),
        findsNothing,
      );
    });
  });
}

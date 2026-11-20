import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/domain/services/organize_criterion.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/shelf_organize_controller.dart';
import 'package:kitaplik/presentation/pages/organize_setup_page.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoriler kartının kurulum sayfası akışı: 1.19.0'da favoriler
/// YALNIZ "Yazara göre" kriteri seçilince görünür ve devreye girer;
/// önizleme favori rafı yıldız rozetiyle gösterir. Doluluk cm + kitap
/// sayısıyla yazılır.
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

BookModel book(String id, String shelf, String author) => BookModel(
      id: id,
      title: 'Kitap $id',
      authors: [author],
      shelf: shelf,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  late FakeBookRepository repository;
  late ShelfOrganizeController controller;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      book('b1', 'Raf 1', 'Ece Temelkuran'),
      book('b2', 'Raf 1', 'Ece Temelkuran'),
      book('b3', 'Raf 1', 'Ahmet Ümit'),
    ]);
    Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await Get.find<LibraryController>().loadBooks();
    Get.put<ShelfOrganizeController>(
      ShelfOrganizeController(shelfStore: ShelfLocalDataSource(prefs)),
      permanent: true,
    );
    controller = Get.find<ShelfOrganizeController>();
    // 3 kitap × 25 mm = 75 mm; raf başına 2 kitap ≈ 5 cm → 2 raf (10 cm).
    await controller.quickSetup(5);
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpSetup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      home: const OrganizeSetupPage(),
    ));
    await tester.pumpAndSettle();
  }

  /// Favoriler kartı yalnız "Yazara göre" kriterinde görünür (1.19.0).
  Future<void> selectAuthorCriterion(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('criterion-author')));
    await tester.pumpAndSettle();
  }

  Future<void> pumpPreview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      initialRoute: Routes.organizePreview,
      getPages: AppPages.pages,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Favoriler kartı yalnız "Yazara göre" seçilince görünür',
      (tester) async {
    await pumpSetup(tester);

    // Kriter seçilmeden önce favoriler kartı HİÇ görünmez (1.19.0
    // kullanıcı kararı: başlıklar yalnız yazara göre seçiliyken çıkar).
    expect(find.text('Favoriler'), findsNothing);

    await selectAuthorCriterion(tester);

    expect(find.text('Favoriler'), findsOneWidget);
    // Kriter kartı favorilerden ÖNCE gelir (düzen önce kriter ister).
    final criterionDy =
        tester.getTopLeft(find.text('Kitaplar nasıl dizilsin?')).dy;
    final favoritesDy = tester.getTopLeft(find.text('Favoriler')).dy;
    expect(criterionDy, lessThan(favoritesDy));
  });

  testWidgets('favori raf seçilir ve favori yazar eklenir', (tester) async {
    await pumpSetup(tester);
    await selectAuthorCriterion(tester);

    final raf2 = controller.shelves.firstWhere((s) => s.name == 'Raf 2');
    await tester.tap(find.byKey(ValueKey('favorite-shelf-${raf2.id}')));
    await tester.pumpAndSettle();
    expect(controller.favoriteShelfId.value, raf2.id);

    await tester.enterText(
      find.byKey(const ValueKey('favorite-author-input')),
      'Ahmet Ümit',
    );
    await tester.tap(find.byKey(const ValueKey('favorite-author-add')));
    await tester.pumpAndSettle();
    expect(controller.favoriteAuthors, contains('Ahmet Ümit'));
    expect(
      find.byKey(const ValueKey('favorite-author-chip-Ahmet Ümit')),
      findsOneWidget,
    );

    // Öneri çipinden eklenen yazar listede görünür.
    await tester.tap(find.byKey(const ValueKey('favorite-suggest-Ece Temelkuran')));
    await tester.pumpAndSettle();
    expect(controller.favoriteAuthors, contains('Ece Temelkuran'));
  });

  testWidgets('favori yazar çipinden silinebilir', (tester) async {
    await controller.addFavoriteAuthor('Ece Temelkuran');
    await pumpSetup(tester);
    await selectAuthorCriterion(tester);

    await tester.tap(
      find.byKey(const ValueKey('favorite-author-chip-Ece Temelkuran')),
      warnIfMissed: false,
    );
    // InputChip silme, çipin sağındaki sil ikonuna dokunulur.
    final chipFinder =
        find.byKey(const ValueKey('favorite-author-chip-Ece Temelkuran'));
    final deleteIcon = find.descendant(
      of: chipFinder,
      matching: find.byTooltip('Delete'),
    );
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    expect(controller.favoriteAuthors, isEmpty);
  });

  testWidgets('kurulum doluluğu kitap sayısı + cm yazar (kalınlık dahili)',
      (tester) async {
    await pumpSetup(tester);

    // 3 kitap (bilinmeyen sayfa = 25 mm) → 7,5 cm; 2 raf × 5 cm = 10 cm.
    // Anahtar kalktı (1.19.0): hesap daima cm, metin kitap sayısını da
    // taşır.
    expect(find.text('3 kitap • 7,5 cm / 10 cm'), findsOneWidget);
    expect(find.byKey(const ValueKey('organize-thickness-switch')),
        findsNothing);
  });

  testWidgets('önizleme favori rafı yıldız rozetiyle gösterir', (tester) async {
    final raf1 = controller.shelves.firstWhere((s) => s.name == 'Raf 1');
    await controller.setFavoriteShelf(raf1.id);
    await controller.addFavoriteAuthor('Ece Temelkuran');
    controller.buildPreview(OrganizeCriterion.author);

    await pumpPreview(tester);

    // Rozet bir kez görünür ve favori rafın kitapları listelenir.
    expect(find.text('Favori raf'), findsOneWidget);
    expect(find.byKey(const ValueKey('planned-Raf 1')), findsOneWidget);
    expect(find.text('Kitap b1'), findsOneWidget);
    expect(find.text('Kitap b2'), findsOneWidget);
  });
}

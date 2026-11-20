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
import 'package:kitaplik/presentation/pages/move_plan_page.dart';
import 'package:kitaplik/presentation/pages/organize_setup_page.dart';
import 'package:kitaplik/presentation/pages/shelf_editor_page.dart';
import 'package:kitaplik/presentation/pages/shelves_page.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raf düzeni asistanının ekran akışı: kurulum kapısı, önizleme, plan
/// işaretleme, düzenleyici ve Raflar sekmesi bandı.
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
      book('b4', 'Raf 1', 'Ahmet Ümit'),
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
    // İki raf, raf başına 2 kitap ≈ 5 cm. Gruplar eşit (2+2): alfabe
    // kırıcısı Ahmet'i önce koyar → Ahmet Raf 1'de kalır, Ece Raf 2'ye
    // taşınır.
    await controller.quickSetup(5);
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      initialRoute: Routes.organizeSetup,
      getPages: AppPages.pages,
      home: page,
    ));
    await tester.pumpAndSettle();
  }

  group('kurulum sayfası', () {
    testWidgets('kriter + onay olmadan "Hedef düzeni oluştur" kapalıdır',
        (tester) async {
      await pumpPage(tester, const OrganizeSetupPage());

      final button =
          tester.widget<FilledButton>(find.byKey(const ValueKey(
        'organize-create-arrangement',
      )));
      expect(button.onPressed, isNull);
    });

    testWidgets('kriter ve onay seçilince düğme açılır ve önizlemeye gider',
        (tester) async {
      await pumpPage(tester, const OrganizeSetupPage());

      await tester.tap(find.byKey(const ValueKey('criterion-author')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('organize-confirm-all-books')));
      await tester.pumpAndSettle();

      final button =
          tester.widget<FilledButton>(find.byKey(const ValueKey(
        'organize-create-arrangement',
      )));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('organize-create-arrangement')));
      await tester.pumpAndSettle();

      // Önizleme sayfası açıldı: planlanan raflar görünür.
      expect(find.text('Hedef düzen (önizleme)'), findsOneWidget);
      expect(find.byKey(const ValueKey('planned-Raf 1')), findsOneWidget);
      expect(find.byKey(const ValueKey('planned-Raf 2')), findsOneWidget);
    });

    testWidgets('raflar tanımsızsa kitap rafları içe aktarılır',
        (tester) async {
      // quickSetup ile raf açıldı; temizleyip içe aktarma yolunu dene.
      controller.shelves.clear();
      await pumpPage(tester, const OrganizeSetupPage());
      await tester.pumpAndSettle();
      // Kitaplarda 'Raf 1' adı geçtiği için içe aktarma 1 raf açar.
      expect(controller.shelves, isNotEmpty);
    });
  });

  group('önizleme sayfası', () {
    testWidgets('hedef düzeni gösterir ve plana geçirir', (tester) async {
      controller.buildPreview(OrganizeCriterion.author);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        initialRoute: Routes.organizePreview,
        getPages: AppPages.pages,
      ));
      await tester.pumpAndSettle();

      // Raf başlıkları (düzen sırası numaralı) ve doluluklar görünür.
      expect(find.text('1. Raf 1'), findsWidgets);
      expect(find.text('2. Raf 2'), findsWidgets);
      // Kitap başlıkları listelenir.
      expect(find.text('Kitap b3'), findsOneWidget);
      expect(find.text('Kitap b4'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('organize-create-plan')));
      await tester.pumpAndSettle();

      // Plan sayfası: tur kartı ve 'Yaptım' düğmesi.
      expect(find.byType(MovePlanPage), findsOneWidget);
      expect(find.textContaining('TUR'), findsWidgets);
      expect(controller.plan.value, isNotNull);
    });
  });

  group('taşıma planı sayfası', () {
    testWidgets('"Yaptım" işareti kitapları hedef rafa yazar', (tester) async {
      controller.buildPreview(OrganizeCriterion.author);
      await controller.createPlan();
      expect(controller.plan.value!.totalMoveCount, 2);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        initialRoute: Routes.organizePlan,
        getPages: AppPages.pages,
      ));
      await tester.pumpAndSettle();

      // Tek tur; emirler görünür: 'Raf 1 rafından şu kitapları al'.
      expect(find.textContaining('rafından şu kitapları al'), findsOneWidget);
      expect(find.textContaining('rafına şu kitapları koy'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tur-done-0')));
      await tester.pumpAndSettle();

      // Onay diyaloğu: 'Yaptım' ile onayla.
      await tester.tap(find.byKey(const ValueKey('tur-done-confirm')));
      await tester.pumpAndSettle();

      // Tamamlama balonu (snackbar) zamanlayıcısını akıt.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Ece kitapları hedef rafına (Raf 2) yazıldı; Ahmet yerinde.
      // Plan tamamlandığı için silindi.
      expect(
        repository.store
            .where((b) => b.authors.first == 'Ece Temelkuran')
            .map((b) => b.shelf),
        everyElement('Raf 2'),
      );
      expect(
        repository.store
            .where((b) => b.authors.first == 'Ahmet Ümit')
            .map((b) => b.shelf),
        everyElement('Raf 1'),
      );
      expect(controller.plan.value, isNull);
    });

    testWidgets('"Yeniden planla" kalıntı işi yeniden kurar', (tester) async {
      controller.buildPreview(OrganizeCriterion.author);
      await controller.createPlan();
      // b1 (Ece) hedefi Raf 2'dir: elle oraya taşı; kalan iş 1 kitap olur.
      final b1 = repository.store.firstWhere((b) => b.id == 'b1');
      await Get.find<LibraryController>()
          .moveToShelf(b1, 'Raf 2');

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        initialRoute: Routes.organizePlan,
        getPages: AppPages.pages,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yeniden planla'));
      await tester.pumpAndSettle();

      expect(controller.plan.value, isNotNull);
      expect(controller.plan.value!.totalMoveCount, 1);
    });
  });

  group('raf düzenleyici', () {
    testWidgets('hızlı kurulum rafları açar', (tester) async {
      controller.shelves.clear();
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        home: const ShelfEditorPage(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('shelf-editor-quick-setup')));
      await tester.pumpAndSettle();
      // Varsayılan 100 cm ile aç: 'Rafları aç' düğmesine bas.
      await tester.tap(find.byKey(const ValueKey('quick-setup-submit')));
      await tester.pumpAndSettle();

      expect(controller.shelves.length, 1); // 4 kitap (100 mm) / 100 cm = 1 raf
      expect(controller.shelves.single.name, 'Raf 1');
    });

    testWidgets('yeni raf diyaloğu raf ekler', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        home: const ShelfEditorPage(),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('shelf-editor-add')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Raf adı'),
        'Balkon',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Uzunluk (cm)'),
        '12',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Yer (kat/oda)'),
        'Üst kat',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(controller.shelves.length, 3); // 2 quick setup + Balkon
      final balkon = controller.shelves
          .firstWhere((s) => s.name == 'Balkon');
      expect(balkon.lengthCm, 12);
      expect(balkon.location, 'Üst kat');
    });
  });

  group('Raflar sekmesi', () {
    testWidgets('plan sürerken ilerleme bandı gösterilir', (tester) async {
      controller.buildPreview(OrganizeCriterion.author);
      await controller.createPlan();

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        home: const ShelvesPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('organize-entry')), findsOneWidget);
      expect(find.text('Taşıma planı sürüyor'), findsOneWidget);
    });

    testWidgets('plan yokken davet kartı gösterilir', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GetMaterialApp(
        home: const ShelvesPage(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Rafları otomatik düzenle'), findsOneWidget);
    });
  });
}

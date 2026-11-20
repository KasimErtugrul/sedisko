import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/loan_local_datasource.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/datasources/wishlist_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/organize_plan_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/domain/services/organize_criterion.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/loan_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/shelf_organize_controller.dart';
import 'package:kitaplik/presentation/controllers/wishlist_controller.dart';
import 'package:kitaplik/presentation/pages/home_page.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FAZ 3 (1.22.0): "saklı sayfaları görünür kıl" — keşke 13, 14, 29.
///
/// Hasan'ın notları: "Kitap listesini beş dakika aradım" (13), "Alt barda
/// dört sekme var; ödünç ve satın alma sayfaları hiçbirinde yok; minik
/// 'Tümü' yazısı gözüme görünmedi bile" (14), "İlerleme kartı Raflar
/// sekmesinde duruyor; ama ben Ana Sayfa'da yaşıyorum" (29).
///
/// Bu testler üç şeyi doğrular: (1) Kısayollar satırı her koşulda görünür
/// ve dört hedefi doğru sayfaya taşır; (2) plan hatırlatma kartı YALNIZ
/// plan sürerken kurulur ve plan sayfasını açar; (3) dar ekranda (360 dp,
/// 1.3 metin ölçeği) hiçbir taşma olmaz.
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

BookModel seed(String id, String title) => BookModel(
      id: id,
      title: title,
      authors: ['Kasım'],
      shelf: 'Roman',
      addedAt: DateTime(2026, 1, 1),
    );

/// Ana sayfa bağlamının istediği bütün denetleyiciler: kitaplık, asistan
/// (plan kartı için), ödünç ve satın alma (kısayolların açtığı sayfalar).
Future<void> putHomeHarness() async {
  Get.testMode = true;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put<SettingsController>(
    SettingsController(prefs: prefs),
    permanent: true,
  );
  Get.put<BookRepository>(FakeBookRepository(initial: [
    seed('b1', 'Simyacı'),
    seed('b2', 'Şeker Portakalı'),
  ]), permanent: true);
  final library = Get.put<LibraryController>(
    LibraryController(Get.find<BookRepository>(), onNotify: (_, __) {}),
    permanent: true,
  );
  await library.loadBooks();
  Get.put<ShelfOrganizeController>(
    ShelfOrganizeController(shelfStore: ShelfLocalDataSource(prefs)),
    permanent: true,
  );
  Get.put<LoanController>(
    LoanController(store: LoanLocalDataSource(prefs), onNotify: (_, __) {}),
    permanent: true,
  );
  Get.put<WishlistController>(
    WishlistController(store: WishlistLocalDataSource(prefs)),
    permanent: true,
  );
}

/// 5 turlu, 2 turu tamamlanmış bir plan: '2/5 gezi tamam' metni üretilir
/// (1.24.0 — keşke 28: ekrandaki "tur" kelimesi "gezi" oldu).
OrganizePlanModel planForTest() {
  MoveTurModel tur(int i) => MoveTurModel(
        location: 'Yer $i',
        actions: [
          MoveActionModel(
            isPickup: true,
            shelf: 'Roman',
            moves: [
              PlanMove(
                bookId: 'b1',
                title: 'Simyacı',
                fromShelf: 'Roman',
                toShelf: 'Tarih',
              ),
            ],
          ),
        ],
      );

  return OrganizePlanModel(
    criterion: OrganizeCriterion.author,
    createdAt: DateTime(2026, 1, 1),
    turs: [for (var i = 0; i < 5; i++) tur(i)],
    completedTurIndexes: [0, 1],
  );
}

void main() {
  tearDown(Get.reset);

  Future<void> pumpHome(
    WidgetTester tester, {
    double width = 400,
    double height = 3000,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(GetMaterialApp(
      getPages: AppPages.pages,
      home: const HomePage(),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  group('ana sayfa kısayolları (keşke 13, 14)', () {
    testWidgets('dört kısayol yazılı düğmeler olarak görünür', (tester) async {
      await putHomeHarness();
      await pumpHome(tester);

      expect(find.byKey(const ValueKey('home-shortcuts')), findsOneWidget);
      // Etiketler satırın İÇİNDE yazılıdır. 'Ödünç verilenler' vb. aynı
      // zamanda bölüm başlıklarının adıdır; bu yüzden eşleşme satıra
      // kapsamlanır (ad tutarlılığı: bir yerin adı her yerde aynı).
      final shortcuts = find.byKey(const ValueKey('home-shortcuts'));
      for (final label in [
        'Tüm kitaplar',
        'Ödünç verilenler',
        'Ödünç aldıkların',
        'Satın alınacaklar',
      ]) {
        expect(
          find.descendant(of: shortcuts, matching: find.text(label)),
          findsOneWidget,
        );
      }
    });

    testWidgets('satır ilk bölüm başlığının ÜSTÜNDE durur', (tester) async {
      await putHomeHarness();
      await pumpHome(tester);

      // Kısayollar özet satırından hemen sonra, bölüm başlıklarından
      // önce gelir: ilk bakışta görülecek yer burasıdır.
      final shortcutsDy =
          tester.getTopLeft(find.byKey(const ValueKey('home-shortcuts'))).dy;
      final firstSectionDy =
          tester.getTopLeft(find.text('Devam eden kitaplar')).dy;
      expect(shortcutsDy < firstSectionDy, isTrue,
          reason: 'kısayollar bölümlerden önce kurulur');
    });

    testWidgets('"Tüm kitaplar" çipi tam kitaplık listesini açar',
        (tester) async {
      await putHomeHarness();
      await pumpHome(tester);

      await tester
          .tap(find.byKey(const ValueKey('home-shortcut-all-books')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.shelf);
      // Raf sayfasının başlığı 'Tüm kitaplar' (çekince yok: ana sayfadaki
      // çip AppBar DEĞİLDİR, kapsamla ayırt edilir).
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Tüm kitaplar'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Ödünç verilenler" çipi ödünç sayfasını açar',
        (tester) async {
      await putHomeHarness();
      await pumpHome(tester);

      await tester.tap(find.byKey(const ValueKey('home-shortcut-loans')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.loans);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Ödünç verilenler'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Ödünç aldıkların" çipi ödünç aldıklarım sayfasını açar',
        (tester) async {
      await putHomeHarness();
      await pumpHome(tester);

      await tester.tap(find.byKey(const ValueKey('home-shortcut-borrowed')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.borrowed);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Ödünç aldıklarım'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Satın alınacaklar" çipi satın alma listesini açar',
        (tester) async {
      await putHomeHarness();
      await pumpHome(tester);

      await tester.tap(find.byKey(const ValueKey('home-shortcut-wishlist')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.wishlist);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Satın alınacaklar'),
        ),
        findsOneWidget,
      );
    });
  });

  group('plan hatırlatma kartı (keşke 29)', () {
    testWidgets('plan yokken kart kurulmaz; kısayollar durur',
        (tester) async {
      await putHomeHarness();
      await pumpHome(tester);

      expect(find.byKey(const ValueKey('home-plan-banner')), findsNothing);
      expect(find.byKey(const ValueKey('home-shortcuts')), findsOneWidget);
    });

    testWidgets('plan sürerken kart görünür ve plan sayfasını açar',
        (tester) async {
      await putHomeHarness();
      Get.find<ShelfOrganizeController>().plan.value = planForTest();
      await pumpHome(tester);

      // Hasan'ın önerdiği cümle: "2/5 tur tamam, devam edelim mi?"
      // (1.24.0 — keşke 28: "tur" kelimesi günlük "gezi" oldu.)
      expect(find.byKey(const ValueKey('home-plan-banner')), findsOneWidget);
      expect(find.text('Taşıma planı sürüyor'), findsOneWidget);
      expect(
        find.textContaining('2/5 gezi tamam'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('home-plan-banner')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, Routes.organizePlan);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Taşıma planı'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('plan bitince kart kaybolur', (tester) async {
      await putHomeHarness();
      final organize = Get.find<ShelfOrganizeController>();
      organize.plan.value = planForTest();
      await pumpHome(tester);
      expect(find.byKey(const ValueKey('home-plan-banner')), findsOneWidget);

      organize.plan.value = null;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-plan-banner')), findsNothing);
    });
  });

  group('dar ekran taşma savunması (360 dp × 1.3)', () {
    testWidgets('kısayollar ve plan kartı küçük ekranda taşmaz',
        (tester) async {
      await putHomeHarness();
      Get.find<ShelfOrganizeController>().plan.value = planForTest();
      await pumpHome(
        tester,
        width: 360,
        height: 900,
        textScale: 1.3,
      );

      // pumpHome zaten takeException denetler; kart ve çipler kuruldu.
      expect(find.byKey(const ValueKey('home-plan-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-shortcuts')), findsOneWidget);
    });
  });
}

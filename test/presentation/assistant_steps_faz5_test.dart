import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/organize_plan_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/domain/services/organize_criterion.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/shelf_organize_controller.dart';
import 'package:kitaplik/presentation/pages/move_plan_page.dart';
import 'package:kitaplik/presentation/pages/organize_preview_page.dart';
import 'package:kitaplik/presentation/pages/organize_setup_page.dart';
import 'package:kitaplik/presentation/pages/shelf_editor_page.dart';
import 'package:kitaplik/presentation/pages/shelves_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.24.0 — keşke notları FAZ 5 ("asistanı adım adım soru soran bir eşe
/// çevir", not 21-28) ekran testleri:
///
/// - keşke 21: "Raf tanımları" ile "Rafları otomatik düzenle" artık iki
///   farklı işin iki farklı adıdır; aynı ekranlarda çakışmazlar.
/// - keşke 22: "Hedef düzeni oluştur" düğmesi kapalıyken NEDEN kapalı
///   olduğunu eksik adımları sayarak yazar.
/// - keşke 23: kurulum kartları numaralı adımlarla kurulur; favoriler
///   "isteğe bağlı"dır ve "Yazara göre" seçilince numaralar kayar.
/// - keşke 25: onay kutusu "neden soruluyor"u günlük dille yazar.
/// - keşke 26: önizlemede taşınan kitaplar ok rozetiyle işaretlidir ve
///   raf başına "Bu rafa N kitap taşınıyor" özeti vardır.
/// - keşke 27: "az taşınma normaldir" notu kurulumda durur.
/// - keşke 28: plan sayfası "gezi" dilini konuşur; aynı yerin devam
///   gezisi "(devam)" yazar; "neden 10 kitap" kartta açıklanır.
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

Future<ShelfOrganizeController> bootstrap(WidgetTester tester) async {
  Get.testMode = true;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put<SettingsController>(
    SettingsController(prefs: prefs),
    permanent: true,
  );
  final repository = FakeBookRepository(initial: [
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
  final controller = Get.put<ShelfOrganizeController>(
    ShelfOrganizeController(shelfStore: ShelfLocalDataSource(prefs)),
    permanent: true,
  );
  await controller.quickSetup(125);
  await controller.addShelf(name: 'Raf 2', lengthCm: 125);
  return controller;
}

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GetMaterialApp(home: page));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    Get.reset();
  });

  group('keşke 22 — gri düğme nedenini söyler', () {
    testWidgets('kapalı düğme eksik adımları sayarak yazar', (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const OrganizeSetupPage());

      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('organize-create-arrangement')),
      );
      expect(button.onPressed, isNull);

      // Eksik adımlar düğmenin altında, günlük dille:
      expect(
        find.byKey(const ValueKey('organize-create-reason')),
        findsOneWidget,
      );
      expect(find.textContaining('dağıtım kriteri seçilmedi'), findsOneWidget);
      expect(find.textContaining('işaretlenmedi'), findsOneWidget);
    });

    testWidgets('kriter + onay tamamlanınca neden kaybolur, düğme açılır',
        (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const OrganizeSetupPage());

      await tester.tap(find.byKey(const ValueKey('criterion-author')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('organize-confirm-all-books')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('organize-create-reason')),
        findsNothing,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('organize-create-arrangement')),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('raf tanımı silinince neden "raf tanımı yok" der',
        (tester) async {
      final controller = await bootstrap(tester);
      await pumpPage(tester, const OrganizeSetupPage());

      // Sayfa açıldıktan sonra raflar silinirse neden satırı anında
      // tazelenir (içe aktarma yalnız initState'te çalışır; burada
      // çalışmaz).
      controller.shelves.clear();
      await tester.pumpAndSettle();

      expect(find.textContaining('raf tanımı yok'), findsOneWidget);
    });
  });

  group('keşke 23 — adım adım kurulum', () {
    testWidgets('kartlar numaralı adımlarla kurulur', (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const OrganizeSetupPage());

      // Kriter seçilmeden favoriler gizlidir: onay 3. adımdır.
      expect(find.textContaining('1. adım — Rafların hazırlığı'),
          findsOneWidget);
      expect(find.textContaining('2. adım'), findsOneWidget);
      expect(find.textContaining('3. adım — Onay'), findsOneWidget);
      expect(find.textContaining('isteğe bağlı'), findsNothing);
    });

    testWidgets('"Yazara göre" seçilince favoriler 3. adım, onay 4. olur',
        (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const OrganizeSetupPage());

      await tester.tap(find.byKey(const ValueKey('criterion-author')));
      await tester.pumpAndSettle();

      expect(find.textContaining('3. adım — Favoriler'), findsOneWidget);
      expect(find.textContaining('isteğe bağlı'), findsOneWidget);
      expect(find.textContaining('4. adım — Onay'), findsOneWidget);
    });

    testWidgets('tamamlanan adımlar onay işareti taşır', (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const OrganizeSetupPage());

      // Raflar hazır: yalnız 1. adım tamam.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('criterion-author')));
      await tester.pumpAndSettle();
      // 1. + 2. adım tamam (favoriler isteğe bağlı, işaret beklenmez).
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('organize-confirm-all-books')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    });
  });

  group('keşke 25 + 27 — dürüst metinler', () {
    testWidgets('onay kutusu neden sorulduğunu yazar', (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const OrganizeSetupPage());

      expect(find.textContaining('Neden soruluyor?'), findsOneWidget);
    });

    testWidgets('"az taşınma normaldir" notu kurulumda durur',
        (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const OrganizeSetupPage());

      expect(
        find.byKey(const ValueKey('organize-few-moves-note')),
        findsOneWidget,
      );
      expect(find.textContaining('hata işareti değil'), findsOneWidget);
    });
  });

  group('keşke 26 — önizlemede taşınanlar işaretli', () {
    testWidgets('taşınan kitap ok rozetiyle ve raf özetiyle görünür',
        (tester) async {
      final controller = await bootstrap(tester);
      // b4'ü Raf 2'ye elle taşı: planlayıcı bütün kitapları Raf 1'e
      // dizer (kapasite yeter), yani b4 planla RAF 1'E taşınır.
      final b4 = Get.find<LibraryController>().books
          .firstWhere((b) => b.id == 'b4');
      await Get.find<LibraryController>().moveToShelf(b4, 'Raf 2');
      controller.buildPreview(OrganizeCriterion.author);

      await pumpPage(tester, const OrganizePreviewPage());

      // Raf 1 kartında raf başına özet: 1 kitap taşınıyor, 3 zaten burada.
      expect(
        find.byKey(const ValueKey('planned-moved-line-Raf 1')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Bu rafa 1 kitap taşınıyor, 3 kitap zaten'),
        findsOneWidget,
      );
      // Taşınan kitabın satırında ok rozeti vardır; yerinde olanlarda yok.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('preview-row-b4')),
          matching: find.byIcon(Icons.subdirectory_arrow_right),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('preview-row-b1')),
          matching: find.byIcon(Icons.subdirectory_arrow_right),
        ),
        findsNothing,
      );
      // Boş kalan Raf 2 kartında taşınma özeti yoktur.
      expect(
        find.byKey(const ValueKey('planned-moved-line-Raf 2')),
        findsNothing,
      );
    });
  });

  group('keşke 28 — geziler günlük dilde', () {
    testWidgets('plan sayfası "gezisi" der ve diyaloğu aynı dili konuşur',
        (tester) async {
      final controller = await bootstrap(tester);
      // b4'ü Raf 2'ye elle taşı: planlayıcı bütün kitapları Raf 1'e
      // dizer; plan bu kez 1 kitap taşır (yoksa plan üretilmez ve
      // sayfa "Aktif plan yok" gösterir).
      final b4 = Get.find<LibraryController>().books
          .firstWhere((b) => b.id == 'b4');
      await Get.find<LibraryController>().moveToShelf(b4, 'Raf 2');
      controller.buildPreview(OrganizeCriterion.author);
      await controller.createPlan();

      await pumpPage(tester, const MovePlanPage());

      expect(controller.plan.value, isNotNull);

      expect(find.textContaining('gezi tamam'), findsOneWidget);
      expect(find.textContaining('1. Yer belirtilmedi gezisi'),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tur-done-0')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('gezisi tamamlandı mı'),
        findsOneWidget,
      );
      expect(find.textContaining('Bu gezideki'), findsOneWidget);

      await tester.tap(find.text('Hayır, daha değil'));
      await tester.pumpAndSettle();
    });

    testWidgets('aynı yerin devam gezisi "(devam)" yazar', (tester) async {
      final controller = await bootstrap(tester);
      MoveTurModel tur(int i) => MoveTurModel(
            location: 'Alt kat',
            actions: [
              MoveActionModel(
                isPickup: i.isEven,
                shelf: 'Raf $i',
                moves: [
                  PlanMove(
                    bookId: 'b$i',
                    title: 'Kitap b$i',
                    fromShelf: 'Raf $i',
                    toShelf: 'Raf ${i + 1}',
                  ),
                ],
              ),
            ],
          );
      controller.plan.value = OrganizePlanModel(
        criterion: OrganizeCriterion.author,
        createdAt: DateTime(2026, 1, 1),
        turs: [tur(0), tur(1)],
      );

      await pumpPage(tester, const MovePlanPage());

      expect(find.textContaining('0/2 gezi tamam'), findsOneWidget);
      expect(find.text('1. Alt kat gezisi'), findsOneWidget);
      expect(find.text('2. Alt kat gezisi (devam)'), findsOneWidget);
      // "Neden 10 kitap?" sorusu kartta yanıt bulur.
      expect(find.textContaining('kolun yorulmasın diye'), findsOneWidget);
    });

    testWidgets('plan yokken davet asistanın tam adını kullanır',
        (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const MovePlanPage());

      expect(
        find.textContaining('Rafları otomatik düzenle'),
        findsOneWidget,
      );
    });
  });

  group('keşke 21 — iki iş, iki ad', () {
    testWidgets('Raflar sekmesinde tanım yolu "Raf tanımları" der',
        (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const ShelvesPage());

      // Çubuğa tooltipsiz ikon koyuldu; adı artık "Raf tanımları".
      expect(find.byTooltip('Raf tanımları'), findsOneWidget);
      // Asistan kartı kendi adını taşır: iki ad aynı ekranda çakışmaz.
      expect(find.text('Rafları otomatik düzenle'), findsOneWidget);
    });

    testWidgets('tanım sayfasının başlığı "Raf tanımları"dır',
        (tester) async {
      await bootstrap(tester);
      await pumpPage(tester, const ShelfEditorPage());

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Raf tanımları'),
        ),
        findsOneWidget,
      );
    });
  });
}

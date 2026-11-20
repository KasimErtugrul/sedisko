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
import 'package:shared_preferences/shared_preferences.dart';

/// 1.18.1/1.19.0 çıktı-netliği ekran testleri:
/// - önizleme özet kartı ("N kitap taşınacak, M kitap zaten yerinde"
///   + planın raf içi dizilişi kapsamadığı notu),
/// - kurulumda yetim favori raf ipucu (favoriler kartı yalnız yazara
///   göre kriterinde görünür),
/// - büyük turun tembel (kaydırılabilir) kurulumu — arayüz donmasını
///   önleyen davranış.
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

  testWidgets('önizleme özeti taşınacak ve kalan kitabı sayıyla yazar',
      (tester) async {
    final controller = await bootstrap(tester);
    final b4 = Get.find<LibraryController>().books.firstWhere(
          (b) => b.id == 'b4',
        );
    // b4'ü Raf 2'ye elle taşı; planlayıcı Ece grubunu tek rafta tutmak
    // isteyeceğinden en az bir kitap taşınır.
    await Get.find<LibraryController>().moveToShelf(b4, 'Raf 2');
    controller.buildPreview(OrganizeCriterion.author);

    await pumpPage(tester, const OrganizePreviewPage());

    final summary = controller.previewMoveSummary()!;
    final expected = '${summary.moved} kitap taşınacak, '
        '${summary.untouched} kitap zaten yerinde.';
    expect(find.byKey(const ValueKey('preview-summary')), findsOneWidget);
    expect(find.textContaining('kitap zaten yerinde'),
        findsOneWidget);
    expect(find.textContaining(expected), findsOneWidget);
  });

  testWidgets('taşınacak kitap yoksa özet nedeni açıklar', (tester) async {
    final controller = await bootstrap(tester);
    controller.buildPreview(OrganizeCriterion.author);
    expect(controller.previewMoveSummary()!.moved, 0);

    await pumpPage(tester, const OrganizePreviewPage());

    expect(
      find.textContaining('Taşınacak kitap yok'),
      findsOneWidget,
    );
    expect(find.textContaining('4 kitap zaten yerinde'),
        findsOneWidget);
  });

  testWidgets('kurulum sayfası yetim favori rafı uyarır', (tester) async {
    final controller = await bootstrap(tester);
    // Kayıtlı ama artık var olmayan raf kimliği (hızlı kurulum
    // rafları yeniden açınca kimlikler yenilenir).
    controller.favoriteShelfId.value = 'silinmis-raf-kimligi';
    await controller.addFavoriteAuthor('Ahmet Ümit');

    await pumpPage(tester, const OrganizeSetupPage());
    // Favoriler kartı yalnız "Yazara göre" kriterinde görünür (1.19.0).
    await tester.tap(find.byKey(const ValueKey('criterion-author')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Kayıtlı favori raf bulunamadı'),
      findsOneWidget,
    );
    // 'Yok' çipi seçili durumda görünür (geçerli tercih yok).
    expect(find.byKey(const ValueKey('favorite-shelf-none')), findsOneWidget);
  });

  testWidgets('geçerli favori raf seçiliyken yetim uyarısı çıkmaz',
      (tester) async {
    final controller = await bootstrap(tester);
    await controller.setFavoriteShelf(controller.shelves.first.id);

    await pumpPage(tester, const OrganizeSetupPage());
    await tester.tap(find.byKey(const ValueKey('criterion-author')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Kayıtlı favori raf bulunamadı'),
      findsNothing,
    );
  });

  testWidgets('büyük tur tembel listede kurulur: donma yok', (tester) async {
    final controller = await bootstrap(tester);
    // 40 emirli tek tur: eşik (24) üstü → tembel pencere.
    final actions = <MoveActionModel>[
      for (var i = 0; i < 40; i++)
        MoveActionModel(
          isPickup: true,
          shelf: 'Raf 1',
          moves: [
            PlanMove(
              bookId: 'b$i',
              title: 'Çok Uzun Kitap Adı $i',
              fromShelf: 'Raf 1',
              toShelf: 'Raf 2',
            ),
          ],
        ),
    ];
    controller.plan.value = OrganizePlanModel(
      criterion: OrganizeCriterion.author,
      createdAt: DateTime(2026, 1, 1),
      turs: [
        MoveTurModel(location: 'Yer belirtilmedi', actions: actions),
      ],
    );

    await pumpPage(tester, const MovePlanPage());

    // Tembel pencere anahtarı var; İLK emir görünür ama SON emir henüz
    // kurulmadı (ListView.builder yalnız görünür pencereyi kurar).
    expect(
      find.byKey(const ValueKey('tur-actions-lazy-0')),
      findsOneWidget,
    );
    expect(find.textContaining('Çok Uzun Kitap Adı 0'), findsWidgets);
    expect(
      find.textContaining('Çok Uzun Kitap Adı 39'),
      findsNothing,
      reason: 'son emir pencere dışında kalmalı — tümü bir kerede '
          'kuruluyorsa arayüz büyük kitaplıkta donar',
    );

    // Kaydırınca son emir de kurulur.
    await tester.scrollUntilVisible(
      find.textContaining('Çok Uzun Kitap Adı 39'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('tur-actions-lazy-0')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Çok Uzun Kitap Adı 39'), findsOneWidget);
  });

  testWidgets('küçük tur doğrudan listelenir (pencere anahtarı yok)',
      (tester) async {
    final controller = await bootstrap(tester);
    controller.plan.value = OrganizePlanModel(
      criterion: OrganizeCriterion.author,
      createdAt: DateTime(2026, 1, 1),
      turs: [
        MoveTurModel(location: 'Yer belirtilmedi', actions: [
          MoveActionModel(
            isPickup: true,
            shelf: 'Raf 1',
            moves: [
              const PlanMove(
                bookId: 'b1',
                title: 'Küçük tur kitabı',
                fromShelf: 'Raf 1',
                toShelf: 'Raf 2',
              ),
            ],
          ),
          MoveActionModel(
            isPickup: false,
            shelf: 'Raf 2',
            moves: [
              const PlanMove(
                bookId: 'b1',
                title: 'Küçük tur kitabı',
                fromShelf: 'Raf 1',
                toShelf: 'Raf 2',
              ),
            ],
          ),
        ]),
      ],
    );

    await pumpPage(tester, const MovePlanPage());

    expect(find.byKey(const ValueKey('tur-actions-lazy-0')), findsNothing);
    // Aynı kitap AL ve KOY emirlerinde iki kez listelenir.
    expect(find.textContaining('Küçük tur kitabı'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('tur-done-0')), findsOneWidget);
  });

  testWidgets('kapsama tam olduğunda kapsam kartı çıkar, dışarı kartı çıkmaz',
      (tester) async {
    final controller = await bootstrap(tester);
    // 1.19.2: planın kapsama kümesi tüm kitaplığı içerir; plan yalnız 1
    // kitap taşır. Taşınmayan 3 kitap "sonra eklenmiş" DEĞİL — kapsam
    // kartı bunu açıkça yazar, yanlış dışarı uyarısı gösterilmez.
    controller.plan.value = OrganizePlanModel(
      criterion: OrganizeCriterion.author,
      createdAt: DateTime(2026, 1, 1),
      turs: [
        MoveTurModel(location: 'Yer belirtilmedi', actions: [
          MoveActionModel(isPickup: true, shelf: 'Raf 1', moves: [
            const PlanMove(
              bookId: 'b1',
              title: 'Kitap b1',
              fromShelf: 'Raf 1',
              toShelf: 'Raf 2',
            ),
          ]),
          MoveActionModel(isPickup: false, shelf: 'Raf 2', moves: [
            const PlanMove(
              bookId: 'b1',
              title: 'Kitap b1',
              fromShelf: 'Raf 1',
              toShelf: 'Raf 2',
            ),
          ]),
        ]),
      ],
      coveredBookIds: const ['b1', 'b2', 'b3', 'b4'],
    );

    await pumpPage(tester, const MovePlanPage());

    expect(find.byKey(const ValueKey('plan-coverage')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-outsiders')), findsNothing);
    expect(
      find.textContaining('kitaplığın tamamını kapsıyor'),
      findsOneWidget,
    );
  });

  testWidgets('kapsama dışındaki kitaplar dışarı kartıyla bildirilir',
      (tester) async {
    final controller = await bootstrap(tester);
    // Yalnız b1 kapsamda: b2, b3, b4 kapsam dışı → dışarı kartı.
    controller.plan.value = OrganizePlanModel(
      criterion: OrganizeCriterion.author,
      createdAt: DateTime(2026, 1, 1),
      turs: [
        MoveTurModel(location: 'Yer belirtilmedi', actions: [
          MoveActionModel(isPickup: true, shelf: 'Raf 1', moves: [
            const PlanMove(
              bookId: 'b1',
              title: 'Kitap b1',
              fromShelf: 'Raf 1',
              toShelf: 'Raf 2',
            ),
          ]),
        ]),
      ],
      coveredBookIds: const ['b1'],
    );

    await pumpPage(tester, const MovePlanPage());

    expect(find.byKey(const ValueKey('plan-outsiders')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-coverage')), findsNothing);
    expect(
      find.textContaining('3 kitap plan yapıldıktan sonra eklendi'),
      findsOneWidget,
    );
  });
}

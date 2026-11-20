import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/services/book_photo_picker.dart';
import 'package:kitaplik/data/services/cover_photo_store.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/book_form_controller.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/shelf_organize_controller.dart';
import 'package:kitaplik/presentation/pages/organize_setup_page.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:kitaplik/presentation/routes/route_args.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FAZ 2 (1.21.0): "ikonlara yazıyı giydirmek" — keşke 9 ve sayfa
/// gövdesindeki yazısız ikonlar. Anahtarlar ve tooltip'ler aynen
/// korunur; bu testler etiketin düğmenin içinde yazılı olduğunu,
/// kapalı/açık durumların doğru çalıştığını ve davranışın
/// bozulmadığını doğrular.
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

/// Form grubunun demeti: kitap formu hedef testiyle aynı kurulum.
Future<void> putFormHarness() async {
  Get.testMode = true;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put<SettingsController>(
    SettingsController(prefs: prefs),
    permanent: true,
  );
  Get.put<CoverPhotoStore>(CoverPhotoStore(), permanent: true);
  Get.put<BookPhotoPicker>(ImagePickerBookPhotoPicker(), permanent: true);
  Get.put<BookRepository>(FakeBookRepository(), permanent: true);
  final library = Get.put<LibraryController>(
    LibraryController(Get.find<BookRepository>(), onNotify: (_, __) {}),
    permanent: true,
  );
  await library.loadBooks();
}

/// Raf grubunun demeti: eşleşme testiyle aynı kurulum.
Future<void> putShelfHarness() async {
  Get.testMode = true;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  Get.put<SettingsController>(
    SettingsController(prefs: prefs),
    permanent: true,
  );
  final library = Get.put<LibraryController>(
    LibraryController(
      FakeBookRepository(initial: [book('b1', 'Raf 1', 'Yazar A')]),
      onNotify: (_, __) {},
    ),
    permanent: true,
  );
  await library.loadBooks();
  Get.put<ShelfOrganizeController>(
    ShelfOrganizeController(shelfStore: ShelfLocalDataSource(prefs)),
    permanent: true,
  );
}

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(GetMaterialApp(
    getPages: AppPages.pages,
    home: page,
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  tearDown(Get.reset);

  group('kitap formu ISBN eylemleri (keşke 9)', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.pumpWidget(GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ));
      await tester.pumpAndSettle();
      Get.toNamed(
        Routes.form,
        arguments: BookFormArgs(book: BookModel.blank()),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('ISBN boşken "İnternetten getir" kapalıdır ve nedeni yazılıdır',
        (tester) async {
      await putFormHarness();
      await openForm(tester);

      await tester.scrollUntilVisible(
        find.text('İnternetten getir'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Etiket düğmenin içinde yazılıdır.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('isbn-fetch')),
          matching: find.text('İnternetten getir'),
        ),
        findsOneWidget,
      );
      // ISBN boş: düğme kapalı, nedeni yardımcı metinde.
      final button =
          tester.widget<OutlinedButton>(find.byKey(const ValueKey('isbn-fetch')));
      expect(button.onPressed, isNull);
      expect(
        find.text('Bilgileri internetten getirmek için önce ISBN yazın'),
        findsOneWidget,
      );
    });

    testWidgets('ISBN yazılınca "İnternetten getir" açılır', (tester) async {
      await putFormHarness();
      await openForm(tester);

      Get.find<BookFormController>().isbnCtrl.text = '9780140328728';
      await tester.pumpAndSettle();

      final button =
          tester.widget<OutlinedButton>(find.byKey(const ValueKey('isbn-fetch')));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('"Barkod tara" formda yazılı düğmedir', (tester) async {
      await putFormHarness();
      await openForm(tester);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('isbn-scan')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('isbn-scan')),
          matching: find.text('Barkod tara'),
        ),
        findsOneWidget,
      );
    });
  });

  group('asistan kurulum kartında yazılı "Raf tanımları" (1.24.0 adı)', () {
    testWidgets('hazırlık kartında yazılı düğme vardır ve taşmaz',
        (tester) async {
      await putShelfHarness();
      await pumpPage(tester, const OrganizeSetupPage());

      // Yazılı etiket düğmenin içinde (kart içi, çubuk değil).
      // Keşke 21 (1.24.0): eski ad "Rafları düzenle" asistanla
      // çakışıyordu; bu yol artık her yerde "Raf tanımları".
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('organize-open-editor')),
          matching: find.text('Raf tanımları'),
        ),
        findsOneWidget,
      );
      // Tooltip aynen durur (ekran okuyucu yolu), adı yeni adla aynı.
      expect(find.byTooltip('Raf tanımları'), findsOneWidget);
      // 360dp × 1.3 metin ölçeğinde taşma yok (pumpPage zaten denetler).
    });

    testWidgets('düğme düzenleyiciyi açar', (tester) async {
      await putShelfHarness();
      await pumpPage(tester, const OrganizeSetupPage());

      await tester.tap(find.byKey(const ValueKey('organize-open-editor')));
      await tester.pumpAndSettle();

      // Düzenleyici açıldı: çubuğundaki "Hızlı kurulum" ikonunun
      // tooltip'i görünür (çubuk aksiyonu bilinçli olarak ikon kaldı).
      expect(find.byTooltip('Hızlı kurulum'), findsOneWidget);
    });
  });
}

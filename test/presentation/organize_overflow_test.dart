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
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raf düzeni asistanı sayfalarının taşma savunması: en dar ekran
/// (360 dp) × en büyük yazı boyutu (1.3×) × uzun başlık/yazar/yer
/// metinleriyle tek taşma bile istisna düşmez.
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

const _longTitle =
    'Çok Ama Çok Uzun Adlı Bir Kitabın Buraya Kadar Gelen Başlığı '
    'Ve Devam Eden Son Sözleriyle Birlikte Tam Hali';
const _longAuthor = 'Ahmet BirİkiÜçDörtBeş Uzunuzun SoyadıÇokUzun';
const _longLocation = 'Çatı Katındaki Küçük Odanın Batı Cephesindeki Raf';

List<BookModel> longBooks() => [
      for (var i = 1; i <= 6; i++)
        BookModel(
          id: 'b$i',
          title: '$_longTitle ($i)',
          authors: [_longAuthor],
          publisher: 'Uzunuuu Yayınevi ve Ortakları',
          shelf: i <= 3 ? 'Salonun Uun Rafı' : 'Mutfaktaki Ara Raf',
          addedAt: DateTime(2026, 1, 1),
        ),
    ];

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
    repository = FakeBookRepository(initial: longBooks());
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
    await controller.addShelf(
      name: 'Salonun Uun Rafı',
      capacity: 2,
      location: _longLocation,
    );
    await controller.addShelf(
      name: 'Mutfaktaki Ara Raf',
      capacity: 2,
      location: _longLocation,
    );
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpOrganizePage(
    WidgetTester tester,
    String initialRoute,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(GetMaterialApp(
      initialRoute: initialRoute,
      getPages: AppPages.pages,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('kurulum sayfası 360dp × 1.3 taşmaz', (tester) async {
    await pumpOrganizePage(tester, Routes.organizeSetup);
  });

  testWidgets('raf düzenleyici 360dp × 1.3 taşmaz', (tester) async {
    await pumpOrganizePage(tester, Routes.shelfEditor);
  });

  testWidgets('önizleme sayfası 360dp × 1.3 taşmaz', (tester) async {
    controller.buildPreview(OrganizeCriterion.author);
    await pumpOrganizePage(tester, Routes.organizePreview);
  });

  testWidgets('taşıma planı sayfası 360dp × 1.3 taşmaz', (tester) async {
    controller.buildPreview(OrganizeCriterion.author);
    await controller.createPlan();
    await pumpOrganizePage(tester, Routes.organizePlan);
  });
}

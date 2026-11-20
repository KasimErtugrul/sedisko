import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/services/book_photo_picker.dart';
import 'package:kitaplik/data/services/cover_photo_store.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:kitaplik/presentation/utils/app_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppNav.pop'un GetX 4.x snackbar uyumluluk davranışına karşı koruması.
///
/// GetX 4.x'te `Get.back()`, açık bir snackbar varsa onu kapatıp ROTA POP
/// ETMEDEN döner (get 4.7 extension_navigation.dart). Kullanıcı raporu:
/// "Open Library'de bulunamadı" bildirimi hâlâ açıkken hızlıca
/// 'Kendim yazacağım'a basılırsa sheet açık kalır, form üstüne biner;
/// Kaydet deyince kullanıcı ana sayfada sheet'le birlikte kalır
/// ("ana sayfaya atıyor").
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

/// Form bağlamının istediği fotoğraf servislerinin bellek içi halleri.
class FakeCoverPhotoStore implements CoverPhotoStore {
  @override
  Future<String> saveFromTemp(String sourcePath) async => '/fake/covers/x.jpg';

  @override
  Future<void> delete(String? path) async {}
}

class FakeBookPhotoPicker implements BookPhotoPicker {
  @override
  Future<String?> takePhoto() async => null;

  @override
  Future<String?> pickFromGallery() async => null;
}

BookModel seed(String id, String title) => BookModel(
      id: id,
      title: title,
      authors: const ['Kasım'],
      shelf: 'Roman',
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    Get.put<CoverPhotoStore>(FakeCoverPhotoStore(), permanent: true);
    Get.put<BookPhotoPicker>(FakeBookPhotoPicker(), permanent: true);
    final repository = FakeBookRepository(initial: [
      seed('b1', 'Simyacı'),
    ]);
    Get.put<BookRepository>(repository, permanent: true);
    final controller = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await controller.loadBooks();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Get.back() açık bildirimle sayfayı pop etmez (GetX 4.x)',
      (tester) async {
    await pumpApp(tester);

    Get.toNamed(Routes.detail, arguments: 'b1');
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.detail);

    Get.snackbar('Deneme bildirim', 'hâlâ açık',
        snackPosition: SnackPosition.BOTTOM);
    await tester.pumpAndSettle();

    Get.back();
    await tester.pumpAndSettle();

    // GetX 4.x: yalnız bildirim kapanır, sayfa yerinde kalır.
    expect(Get.currentRoute, Routes.detail);
    expect(find.text('Deneme bildirim'), findsNothing);
  });

  testWidgets('AppNav.pop açık bildirimde de rotayı pop eder', (tester) async {
    await pumpApp(tester);

    Get.toNamed(Routes.detail, arguments: 'b1');
    await tester.pumpAndSettle();
    expect(Get.currentRoute, Routes.detail);

    Get.snackbar('Deneme bildirim', 'hâlâ açık',
        snackPosition: SnackPosition.BOTTOM);
    await tester.pumpAndSettle();

    // Navigator pop'u bildirimden etkilenmez; bildirim kendi zamanlayıcısıyla
    // kaybolur (GetX'in closeCurrentSnackbar'ı disposed bildirimde patladığı
    // için AppNav bildirime dokunmaz).
    AppNav.pop();
    await tester.pumpAndSettle();

    expect(Get.currentRoute, Routes.home);

    // Bildirimin otomatik kapanma zamanlayıcısını tüketir.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('bildirim açıkken Kendim yazacağım: sheet kapanır, form üstte olur',
      (tester) async {
    await pumpApp(tester);

    // Kullanıcı senaryosu: barkod bulunamayınca gösterilen bildirim hâlâ
    // açıkken kullanıcı hızlıca Kendim yazacağım'a basar.
    Get.snackbar(
      "Open Library'de bulunamadı",
      'Bilgileri elle girebilirsin. ISBN senin için dolduruldu.',
      snackPosition: SnackPosition.TOP,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kendim yazacağım'));
    await tester.pumpAndSettle();

    // Form açıldı VE alt sheet kapandı; sheet açık kalsaydı Kaydet'te
    // kullanıcı ana sayfada sheet'le kalırdı (bildirilen hata).
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Yeni kitap'),
      ),
      findsOneWidget,
    );
    expect(find.text('Kendim yazacağım'), findsNothing);

    // Bildirimin otomatik kapanma zamanlayıcısını tüketir.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

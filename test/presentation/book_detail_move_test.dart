import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/services/book_photo_picker.dart';
import 'package:kitaplik/data/services/cover_photo_store.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/book_form_controller.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detay sayfası: raf kartından taşıma, kopyalar kartı ve aynı ISBN
/// taramasında "yeni kopya ekle" akışı.
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

void main() {
  late FakeBookRepository repository;
  late LibraryController controller;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      BookModel(
        id: 'b1',
        title: 'Simyacı',
        authors: ['Orhan Pamuk'],
        shelf: 'Roman',
        isbn: '978-3-16-148410-0',
        addedAt: DateTime(2026, 1, 1),
      ),
      BookModel(
        id: 'b2',
        title: 'Simyacı',
        authors: ['Orhan Pamuk'],
        shelf: 'Yatak Odası',
        isbn: '9783161484100', // b1 ile aynı ISBN: kopya
        status: ReadingStatus.reading,
        currentPage: 40,
        pageCount: 200,
        startedAt: DateTime(2026, 1, 5),
        addedAt: DateTime(2026, 1, 2),
      ),
      BookModel(
        id: 'b3',
        title: 'Dönüşüm',
        authors: ['Franz Kafka'],
        shelf: 'Çalışma',
        addedAt: DateTime(2026, 1, 3),
      ),
    ]);
    // Form sayfası binding'i BookRepository'yi Get.find ile çeker;
    // sahte repository arabirim adıyla da kayıtlı olmalı. Form binding
    // ayrıca foto deposu ve kamera kaynağını ister (bu test fotoğraf
    // eklemediği için hiçbir platform kanalına dokunulmaz).
    Get.put<BookRepository>(repository, permanent: true);
    Get.put<CoverPhotoStore>(CoverPhotoStore(), permanent: true);
    Get.put<BookPhotoPicker>(ImagePickerBookPhotoPicker(), permanent: true);
    controller = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await controller.loadBooks();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // Detay sayfası uzun; tüm kartlar (raf, okuma, kopyalar) tek ekranda
    // görünsün diye test yüzeyi yüksek tutulur.
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
  }

  Future<void> pumpDetail(WidgetTester tester, String bookId) async {
    await pumpApp(tester);
    Get.toNamed(Routes.detail, arguments: bookId);
    await tester.pumpAndSettle();
  }

  /// Snackbar'ın 3 sn'lik kapanma zamanlayıcısını sahte saatte tüketir;
  /// aksi halde "Timer is still pending" hatası ve GetX snack kuyruğu
  /// sonraki testleri bloklar.
  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('raf kartından dokunup kitabı başka rafa taşır',
      (tester) async {
    await pumpDetail(tester, 'b1');

    // Raf kartı: mevcut raf adı + dokunma hedefi.
    expect(find.text('Raf'), findsOneWidget);
    expect(find.text('Roman'), findsOneWidget);

    await tester.tap(find.text('Raf'));
    await tester.pumpAndSettle();

    expect(find.text('Kitabı hangi rafa taşımak istersin?'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(ListTile), matching: find.text('Çalışma')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // Taşındı bilgisi + kart güncellendi + depoya yazıldı.
    expect(find.text('Taşındı'), findsOneWidget);
    expect(controller.byId('b1')!.shelf, 'Çalışma');
    expect(repository.store.firstWhere((b) => b.id == 'b1').shelf, 'Çalışma');
    await drainSnackbars(tester);
  });

  testWidgets('taşıma kopyanın bağımsız okuma durumunu bozmaz',
      (tester) async {
    await pumpDetail(tester, 'b1');

    await tester.tap(find.text('Raf'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(ListTile), matching: find.text('Rafsız')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // b1 rafsız oldu; b2 (kopya) okumaya kaldığı yerden devam eder.
    expect(controller.byId('b1')!.shelf, '');
    final copy = controller.byId('b2')!;
    expect(copy.shelf, 'Yatak Odası');
    expect(copy.status, ReadingStatus.reading);
    expect(copy.currentPage, 40);
    expect(copy.startedAt, DateTime(2026, 1, 5));
    await drainSnackbars(tester);
  });

  testWidgets('aynı ISBN kopyaları kopyalar kartında listeler',
      (tester) async {
    await pumpApp(tester);
    Get.toNamed(Routes.detail, arguments: 'b1');
    await tester.pumpAndSettle();

    expect(find.text('Bu kitabın 1 kopyası daha var'), findsOneWidget);
    expect(
      find.textContaining('Her kopya kendi başına yaşar'),
      findsOneWidget,
    );
    // Kopya satırı: raf + bağımsız durum bilgisi.
    expect(find.text('Raf: Yatak Odası'), findsOneWidget);
    expect(find.textContaining('Okunuyor'), findsOneWidget);

    // ISBN'i olmayan kitapta kopyalar kartı çıkmaz. İkinci GetMaterialApp
    // pompalamak yerine aynı uygulama içinde gezin (GlobalKey rota
    // durumunu taşır; b1 detayı altta kalırdı).
    Get.back();
    await tester.pumpAndSettle();
    Get.toNamed(Routes.detail, arguments: 'b3');
    await tester.pumpAndSettle();
    expect(find.textContaining('kopyası'), findsNothing);
  });

  testWidgets('kopya satırına dokununca kopyanın detayı açılır',
      (tester) async {
    await pumpDetail(tester, 'b1');

    await tester.tap(find.text('Raf: Yatak Odası'));
    await tester.pumpAndSettle();

    // Artık b2'nin detayıdayız: kendi raf kartı 'Yatak Odası', kopya
    // satırı ise b1'i ('Raf: Roman') gösterir.
    expect(find.text('Yatak Odası'), findsOneWidget);
    expect(find.text('Raf: Roman'), findsOneWidget);
    expect(find.text('Bu kitabın 1 kopyası daha var'), findsOneWidget);
  });

  testWidgets('aynı ISBN taranınca diyaloğundan yeni kopya eklenebilir',
      (tester) async {
    await pumpApp(tester);

    // Aynı ISBN'yi işle: önce diyaloğ düşmeli.
    controller.handleIsbn('978-3-16-148410-0');
    await tester.pumpAndSettle();

    expect(find.text('Bu kitabı zaten eklemişsin'), findsOneWidget);
    expect(find.textContaining('bu ISBN ile kayıtlı'), findsOneWidget);

    await tester.tap(find.text('Yeni kopya ekle'));
    await tester.pumpAndSettle();

    // Sahte depo Open Library'de bulamaz; elle giriş formu ISBN ile açılır.
    expect(find.text('Yeni kitap'), findsOneWidget);
    expect(
      Get.find<BookFormController>().isbnCtrl.text,
      '978-3-16-148410-0',
    );
    // Kayıt henüz yapılmadı: kitaplık sayısı değişmedi.
    expect(controller.books.length, 3);
  });

  testWidgets('aynı ISBN taranıp "Kitabı gör" denirse detay açılır',
      (tester) async {
    await pumpApp(tester);

    controller.handleIsbn('9783161484100'); // kirli biçim, aynı kitap
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kitabı gör'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Kitap detayı'),
      ),
      findsOneWidget,
    );
  });
}

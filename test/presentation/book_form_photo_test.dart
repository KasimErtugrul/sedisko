import 'package:flutter/foundation.dart';
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
import 'package:kitaplik/presentation/routes/route_args.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kitap formu: kamera/galeriden fotoğraf ekleme, kaldırma ve
/// kaydetme sonrası dosya temizliği.
///
/// Not: testWidgets sahte-zaman (FakeAsync) bölgesinde gerçek dosya G/Ç'si
/// tamamlanmadığı için sahte depo tamamen bellek içi çalışır: kayıt yolu
/// üretir, silme kaydını tutar. Test edilen davranış — hangi sırayla
/// kaydedildiği/silindiği ve kayda hangi yolun yazıldığı — budur.
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

/// Kayıt/silme takibi yapan bellek içi sahte fotoğraf deposu.
class FakeCoverPhotoStore implements CoverPhotoStore {
  final savedPaths = <String>[];
  final deletedPaths = <String>[];

  /// Sahte diskte hâlâ var olan dosyalar.
  final existing = <String>{};
  int _n = 0;

  @override
  Future<String> saveFromTemp(String sourcePath) async {
    _n++;
    final path = '/fake/covers/cover_$_n.jpg';
    savedPaths.add(path);
    existing.add(path);
    return path;
  }

  @override
  Future<void> delete(String? path) async {
    if (path == null) return;
    deletedPaths.add(path);
    existing.remove(path);
  }
}

/// Kamera/galeri yerine sahte kaynak; [path] test içinde değiştirilebilir.
class FakeBookPhotoPicker implements BookPhotoPicker {
  FakeBookPhotoPicker({this.path, this.error});

  String? path;
  Object? error;

  @override
  Future<String?> takePhoto() async {
    if (error != null) throw error!;
    return path;
  }

  @override
  Future<String?> pickFromGallery() async => path;
}

void main() {
  late FakeBookRepository repository;
  late FakeCoverPhotoStore fakeStore;
  late FakeBookPhotoPicker fakePicker;
  late LibraryController controller;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );

    fakeStore = FakeCoverPhotoStore();
    fakePicker = FakeBookPhotoPicker(path: '/fake/temp/kaynak.jpg');

    Get.put<CoverPhotoStore>(fakeStore, permanent: true);
    Get.put<BookPhotoPicker>(fakePicker, permanent: true);

    repository = FakeBookRepository();
    Get.put<BookRepository>(repository, permanent: true);
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
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openForm(
    WidgetTester tester, {
    BookModel? book,
    bool isEdit = false,
  }) async {
    // Form uzadı (keşke 7: 'Diğer bilgiler' bölümü eklendi): fotoğraf
    // düğmelerinin ListView tembel kurulumuna takılmaması için tek ekrana
    // sığacak kadar yüksek yüzey kullanılır (öteki form testlerindeki
    // gibi).
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    Get.toNamed(
      Routes.form,
      arguments: BookFormArgs(book: book, isEdit: isEdit),
    );
    await tester.pumpAndSettle();
    // Keşke 7 (1.26.0): kapak/fotoğraf bölümü 'Diğer bilgiler' katlanabilir
    // bölümüne taşındı; temiz yeni kitapta kapalı gelir, açılır. Açık
    // olduğunu göstergesi bölüm içi 'Okuma durumu' başlığıdır (düzenleme
    // ve getirilen veride bölüm kendiliğinden açılır).
    if (find.text('Okuma durumu').evaluate().isEmpty) {
      await tester.tap(find.text('Diğer bilgiler (isteğe bağlı)'));
      await tester.pumpAndSettle();
    }
  }

  /// Snackbar'ın 3 sn'lik kapanma zamanlayıcısını sahte saatte tüketir.
  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  /// Kaydet düğmesi uzun formda ekran altında kalır; ListView tembel
  /// kurduğundan önce aşağı kaydırıp görünür yapmalıyız.
  Future<void> scrollToSave(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Kaydet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  BookModel existingBookWithPhoto(String oldPath) => BookModel(
        id: 'b1',
        title: 'Eski Kitap',
        shelf: 'Raf B',
        addedAt: DateTime(2026, 1, 1),
        coverPath: oldPath,
      );

  testWidgets('kamera fotoğrafı forma eklenir ve kayıtta coverPath yazılır',
      (tester) async {
    await openForm(tester, book: BookModel.blank());

    final form = Get.find<BookFormController>();
    form.titleCtrl.text = 'Fotoğraflı Kitap';
    form.shelfCtrl.text = 'Raf A';

    await tester.tap(find.text('Kitabın fotoğrafını çek'));
    await tester.pumpAndSettle();

    expect(find.text('Kaldır'), findsOneWidget);
    expect(form.coverPath.value, fakeStore.savedPaths.single);
    expect(fakeStore.existing, contains(form.coverPath.value));

    await scrollToSave(tester);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await drainSnackbars(tester);

    final saved =
        repository.store.singleWhere((b) => b.title == 'Fotoğraflı Kitap');
    expect(saved.coverPath, fakeStore.savedPaths.single);
    expect(fakeStore.existing, contains(saved.coverPath));
  });

  testWidgets('galeriden seçim de aynı şekilde çalışır', (tester) async {
    await openForm(tester, book: BookModel.blank());

    final form = Get.find<BookFormController>();
    form.titleCtrl.text = 'Galeri Kitabı';
    form.shelfCtrl.text = 'Raf C';

    await tester.tap(find.text('Galeriden seç'));
    await tester.pumpAndSettle();

    expect(form.coverPath.value, fakeStore.savedPaths.single);
    expect(fakeStore.existing, contains(form.coverPath.value));
  });

  testWidgets('fotoğraf kaldırılıp kaydedilirse eski dosya silinir',
      (tester) async {
    const oldPath = '/fake/covers/eski.jpg';
    fakeStore.existing.add(oldPath);
    repository.store.add(existingBookWithPhoto(oldPath));
    await controller.loadBooks();

    await openForm(
      tester,
      book: repository.store.first,
      isEdit: true,
    );

    expect(find.text('Kaldır'), findsOneWidget);
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();
    expect(find.text('Kaldır'), findsNothing);

    await scrollToSave(tester);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await drainSnackbars(tester);

    expect(controller.byId('b1')!.coverPath, isNull);
    expect(fakeStore.deletedPaths, contains(oldPath));
    expect(fakeStore.existing, isNot(contains(oldPath)));
  });

  testWidgets('kaydetmeden vazgeçmek orijinal fotoğrafı silmez',
      (tester) async {
    const oldPath = '/fake/covers/eski2.jpg';
    fakeStore.existing.add(oldPath);
    repository.store.add(existingBookWithPhoto(oldPath));
    await controller.loadBooks();

    await openForm(
      tester,
      book: repository.store.first,
      isEdit: true,
    );

    // Yeni fotoğraf çekilir (etiket: fotoğraf zaten varken "Fotoğraf çek").
    await tester.tap(find.text('Fotoğraf çek'));
    await tester.pumpAndSettle();

    final form = Get.find<BookFormController>();
    expect(form.coverPath.value, isNot(oldPath));

    // Kaydetmeden çık.
    Get.back();
    await tester.pumpAndSettle();

    expect(fakeStore.deletedPaths, isNot(contains(oldPath)));
    expect(fakeStore.existing, contains(oldPath));
  });

  testWidgets('aynı oturumda yeniden çekince ara dosya temizlenir',
      (tester) async {
    await openForm(tester, book: BookModel.blank());

    final form = Get.find<BookFormController>();
    form.titleCtrl.text = 'İki Çekim';
    form.shelfCtrl.text = 'Raf D';

    await tester.tap(find.text('Kitabın fotoğrafını çek'));
    await tester.pumpAndSettle();
    final firstPath = form.coverPath.value;

    fakePicker.path = '/fake/temp/kaynak2.jpg';
    await tester.tap(find.text('Fotoğraf çek'));
    await tester.pumpAndSettle();

    expect(form.coverPath.value, fakeStore.savedPaths.last);
    expect(fakeStore.deletedPaths, contains(firstPath));
    expect(fakeStore.existing, isNot(contains(firstPath)));
    expect(fakeStore.existing, contains(form.coverPath.value));
  });

  testWidgets('kamera kullanılamazsa uyarı gösterilir', (tester) async {
    fakePicker.error = Exception('kamera yok');
    await openForm(tester, book: BookModel.blank());

    final form = Get.find<BookFormController>();
    form.titleCtrl.text = 'Hatalı';
    form.shelfCtrl.text = 'Raf E';

    await tester.tap(find.text('Kitabın fotoğrafını çek'));
    await tester.pumpAndSettle();

    expect(find.text('Fotoğraf eklenemedi'), findsOneWidget);
    expect(form.coverPath.value, isNull);
    await drainSnackbars(tester);
  });

  testWidgets('masaüstünde fotoğraf aksiyonları gizlenir', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    // Sıfırlama gövde içinde try/finally ile yapılır. Eski Flutter SDK'lar
    // foundation değişken denetimini test gövdesi biter bitmez, kullanıcı
    // addTearDown'ları çalışmadan önce yapar; o sıralamada addTearDown
    // yetersiz kalır ve "foundation debug variable" hatası düşer. Gövde içi
    // sıfırlama hem eski hem yeni SDK'larda güvenlidir.
    try {
      await openForm(tester, book: BookModel.blank());

      expect(find.text('Kitabın fotoğrafını çek'), findsNothing);
      expect(find.text('Galeriden seç'), findsNothing);
      expect(find.text('Kaldır'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

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

/// Form çıkış onayı (1.16.0, kullanıcı isteği): "kullanıcı birşeyler
/// yazmaya başlıyor, yanlışlıkla appbar'da geriye basıyor ve geri gidiyor.
/// hoppp yazdıkları boşa gitti. bir showDialog ile sorsa 'çıkmak istediğiniz
/// den emin misiniz' diye."
///
/// - Temiz formda geri soru sormadan açılır.
/// - Yazı yazılmışsa (kirli form) "Çıkmak istediğinden emin misin?"
///   diyaloğu çıkar; Vazgeç formda kalır, Çık yazılanları bırakır.
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
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    Get.put<CoverPhotoStore>(CoverPhotoStore(), permanent: true);
    Get.put<BookPhotoPicker>(ImagePickerBookPhotoPicker(), permanent: true);
    final repository = FakeBookRepository();
    Get.put<BookRepository>(repository, permanent: true);
    final library = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await library.loadBooks();
    Get.put<BookFormController>(
      BookFormController(Get.find<BookRepository>(), library),
      permanent: true,
    );
  });

  tearDown(() {
    Get.reset();
  });

  /// Form GERÇEK bir rota olarak açılır (uygulamadaki gibi): PopScope ve
  /// AppNav.pop davranışı root rota yerine yığındaki rotada test edilir.
  Future<void> pumpForm(WidgetTester tester) async {
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
    Get.toNamed(Routes.form, arguments: BookFormArgs(book: BookModel.blank()));
    await tester.pumpAndSettle();
  }

  /// Uygulama çubuğundaki geri düğmesi (Material BackButtonIcon; bu
  /// Flutter sürümünde tester.pageBack Cupertino düğmesini arar).
  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
  }

  testWidgets('temiz formda geri soru sormadan kapanır', (tester) async {
    await pumpForm(tester);

    await tapBack(tester);

    expect(find.text('Çıkmak istediğinden emin misin?'), findsNothing);
    expect(find.text('Yeni kitap'), findsNothing); // sayfa kapandı
  });

  testWidgets('yazı yazınca geri onay diyaloğu açar ve Vazgeç kalır',
      (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kitap adı *'),
      'Yarım kalan kitap',
    );
    await tester.pumpAndSettle();
    expect(Get.find<BookFormController>().isDirty.value, isTrue);

    await tapBack(tester);
    await tester.pumpAndSettle();

    expect(find.text('Çıkmak istediğinden emin misin?'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
    expect(find.text('Çık'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    // Form yerinde, yazdıklarım duruyor.
    expect(find.text('Yeni kitap'), findsOneWidget);
    expect(
      find.text('Yarım kalan kitap'),
      findsOneWidget,
    );
  });

  testWidgets("diyalogda Çık deyince yazdıklarım bırakılıp sayfa kapanır",
      (tester) async {
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kitap adı *'),
      'Kaybolacak yazı',
    );
    await tester.pumpAndSettle();

    await tapBack(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çık'));
    await tester.pumpAndSettle();

    // Sayfa kapandı, hiçbir kayıt yazılmadı.
    expect(find.text('Yeni kitap'), findsNothing);
    expect(find.text('Kaybolacak yazı'), findsNothing);
  });

  testWidgets('yazılan geri alınırsa form temiz kabul edilir', (tester) async {
    await pumpForm(tester);

    final title = find.widgetWithText(TextFormField, 'Kitap adı *');
    await tester.enterText(title, 'geçici');
    await tester.pumpAndSettle();
    expect(Get.find<BookFormController>().isDirty.value, isTrue);

    await tester.enterText(title, '');
    await tester.pumpAndSettle();
    expect(Get.find<BookFormController>().isDirty.value, isFalse);

    await tapBack(tester);
    expect(find.text('Çıkmak istediğinden emin misin?'), findsNothing);
    expect(find.text('Yeni kitap'), findsNothing);
  });

  testWidgets('kirli formda Kaydet başarıyla kapanır, diyalog çıkmaz',
      (tester) async {
    final repository = Get.find<BookRepository>() as FakeBookRepository;
    await pumpForm(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kitap adı *'),
      'Kayıtlı Kitap',
    );
    final form = Get.find<BookFormController>();
    form.shelfCtrl.text = 'Raf A';
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Kaydet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4)); // snackbar + pop
    await tester.pumpAndSettle();

    expect(find.text('Çıkmak istediğinden emin misin?'), findsNothing);
    expect(find.text('Yeni kitap'), findsNothing); // sayfa kapandı
    expect(repository.store.single.title, 'Kayıtlı Kitap');
  });
}

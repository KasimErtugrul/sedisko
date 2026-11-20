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

/// Kitap formu bitirme hedefi alanı: takvim seçici açılır, seçilen tarih
/// alanda görünür, temizleme düğmesi kaldırır ve kayıtta
/// [BookModel.targetFinishDate] olarak saklanır.
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
    repository = FakeBookRepository();
    Get.put<BookRepository>(repository, permanent: true);
    final library = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await library.loadBooks();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> openForm(WidgetTester tester) async {
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
    Get.toNamed(
      Routes.form,
      arguments: BookFormArgs(book: BookModel.blank()),
    );
    await tester.pumpAndSettle();
    // Keşke 7 (1.26.0): bitirme hedefi 'Diğer bilgiler' bölümünde; temiz
    // yeni kitapta bölüm kapalı gelir, açılır.
    await tester.tap(find.text('Diğer bilgiler (isteğe bağlı)'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollToSave(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Kaydet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillRequiredFields(WidgetTester tester) async {
    final form = Get.find<BookFormController>();
    form.titleCtrl.text = 'Hedefli Kitap';
    form.shelfCtrl.text = 'Raf A';
    await tester.pumpAndSettle();
  }

  testWidgets('hedef alanına dokununca takvim seçici açılır', (tester) async {
    await openForm(tester);

    await tester.tap(find.text('Tarih seç'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Seçiciyi kapat (takvim etkileşimi bu testin konusu değil):
    // hedef yine boş kalır, alan "Tarih seç" yazar.
    Get.back();
    await tester.pumpAndSettle();
    expect(find.text('Tarih seç'), findsOneWidget);
  });

  testWidgets('seçilen hedef tarihi kayıtta saklanır', (tester) async {
    await openForm(tester);
    await fillRequiredFields(tester);

    final form = Get.find<BookFormController>();
    form.targetFinishDate.value = DateTime(2026, 12, 15);
    await tester.pumpAndSettle();

    // Alan seçilen tarihi Türkçe biçimde gösterir.
    expect(find.text('15.12.2026'), findsOneWidget);

    await scrollToSave(tester);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4)); // snackbar zamanlayıcısı
    await tester.pumpAndSettle();

    final saved =
        repository.store.singleWhere((b) => b.title == 'Hedefli Kitap');
    expect(saved.targetFinishDate, DateTime(2026, 12, 15));
  });

  testWidgets('hedef temizleme düğmesi tarihi kaldırır', (tester) async {
    await openForm(tester);
    await fillRequiredFields(tester);

    final form = Get.find<BookFormController>();
    form.targetFinishDate.value = DateTime(2026, 12, 15);
    await tester.pumpAndSettle();
    expect(find.text('15.12.2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Hedefi kaldır'));
    await tester.pumpAndSettle();

    expect(find.text('Tarih seç'), findsOneWidget);
    expect(form.targetFinishDate.value, isNull);
  });

  testWidgets('düzenlemede kayıtlı hedef alana gelir', (tester) async {
    repository.store.add(BookModel(
      id: 'b9',
      title: 'Kayıtlı hedef',
      shelf: 'Raf B',
      addedAt: DateTime(2026, 1, 1),
      targetFinishDate: DateTime(2026, 8, 20),
    ));
    await Get.find<LibraryController>().loadBooks();

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
    Get.toNamed(
      Routes.form,
      arguments: BookFormArgs(
        book: repository.store.first,
        isEdit: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20.08.2026'), findsOneWidget);
    final form = Get.find<BookFormController>();
    expect(form.targetFinishDate.value, DateTime(2026, 8, 20));
  });
}

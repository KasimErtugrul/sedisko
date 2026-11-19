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
import 'package:kitaplik/presentation/pages/book_form_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yazar alanı otomatik tamamlama (1.16.0, kullanıcı isteği):
/// "yazar adını girmeye başlayınca daha önce girilmiş bir yazar ise
/// yazmaya başladığında çıkarsa sevinirim zaman kazanır."
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
  // Yazar alanı: dekor etiketiyle bulunur (InputDecorator altındaki Text).
  final authorsField = find.widgetWithText(TextFormField, 'Yazar(lar)');

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
    final repository = FakeBookRepository(initial: [
      BookModel(
        id: 'b1',
        title: 'Beyaz Kale',
        authors: ['Ahmet Ümit'],
        shelf: 'Raf',
        addedAt: DateTime(2026, 1, 1),
      ),
      BookModel(
        id: 'b2',
        title: 'Fare',
        authors: ['Ayşe Kulin'],
        shelf: 'Raf',
        addedAt: DateTime(2026, 1, 2),
      ),
    ]);
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

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(home: const BookFormPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('yazmaya başlayınca kitaplıktaki yazar önerilir', (tester) async {
    await pumpForm(tester);

    await tester.enterText(authorsField, 'ahm');
    await tester.pumpAndSettle();

    // Türkçe katlama: "ahm" → "Ahmet Ümit".
    expect(find.text('Ahmet Ümit'), findsOneWidget);
  });

  testWidgets('öneriye dokununca ad alana yazılır ve virgül eklenir',
      (tester) async {
    await pumpForm(tester);

    await tester.enterText(authorsField, 'ahm');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahmet Ümit'));
    await tester.pumpAndSettle();

    final form = Get.find<BookFormController>();
    expect(form.authorsCtrl.text, 'Ahmet Ümit, ');
  });

  testWidgets('ikinci yazar virgülden sonra önerilir', (tester) async {
    await pumpForm(tester);

    await tester.enterText(authorsField, 'Ahmet Ümit, ay');
    await tester.pumpAndSettle();

    // "Ahmet Ümit" tam yazılmış; öneri yalnız aktif yazım için: "ay" → Ayşe.
    expect(find.text('Ayşe Kulin'), findsOneWidget);
    // Tam yazılan yazar kendisi önerilmez.
    expect(find.text('Ahmet Ümit').hitTestable(), findsNothing);

    await tester.tap(find.text('Ayşe Kulin'));
    await tester.pumpAndSettle();

    final form = Get.find<BookFormController>();
    expect(form.authorsCtrl.text, 'Ahmet Ümit, Ayşe Kulin, ');
  });

  testWidgets('Türkçe karaktersiz yazım da eşleşir (ü→u)', (tester) async {
    await pumpForm(tester);

    await tester.enterText(authorsField, 'ayse');
    await tester.pumpAndSettle();

    expect(find.text('Ayşe Kulin'), findsOneWidget);
  });

  testWidgets('eşleşme yoksa öneri katmanı açılmaz', (tester) async {
    await pumpForm(tester);

    await tester.enterText(authorsField, 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Ahmet Ümit'), findsNothing);
    expect(find.text('Ayşe Kulin'), findsNothing);
  });

  testWidgets('boş yazımda öneri listesi açılmaz', (tester) async {
    await pumpForm(tester);

    // Alan odaklansa bile aktif yazım boşken öneri çıkmaz (liste kirlenmesin).
    await tester.tap(authorsField);
    await tester.pumpAndSettle();

    expect(find.text('Ahmet Ümit'), findsNothing);
  });
}

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
import 'package:kitaplik/presentation/widgets/author_autocomplete_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manuel kitap ekleme formundaki büyük harf davranışı (1.16.0, kullanıcı
/// isteği): "kitap adı ve yayınevi kısmı da aynı yazarlar kısmındaki gibi
/// boşluktan sonra büyük harfe dönsün."
///
/// Yazar alanındaki davranış `TextCapitalization.words` klavye ipucudur;
/// aynı ipucu artık kitap adı ve yayınevine de uygulanır.
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

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(home: const BookFormPage()));
    await tester.pumpAndSettle();
    // Keşke 7 (1.26.0): 'Diğer bilgiler' bölümü temiz yeni kitapta kapalı
    // gelir; Yayınevi gibi ayrıntı alanlarına dokunmak için açılır.
    await tester.tap(find.text('Diğer bilgiler (isteğe bağlı)'));
    await tester.pumpAndSettle();
  }

  /// [TextFormField] kendi başına textCapitalization sergilemez; alanın
  /// içindeki [TextField] üzerine bakılır.
  TextCapitalization capsOf(WidgetTester tester, Finder finder) {
    final inner = find.descendant(
      of: finder,
      matching: find.byType(TextField),
    );
    final widget = tester.widget<TextField>(inner.first);
    return widget.textCapitalization;
  }

  testWidgets('kitap adı alanı boşluktan sonra büyük harf ipucu alır',
      (tester) async {
    await pumpForm(tester);

    final field = find.widgetWithText(TextFormField, 'Kitap adı *');
    expect(field, findsOneWidget);
    expect(capsOf(tester, field), TextCapitalization.words);
  });

  testWidgets('yayınevi alanı boşluktan sonra büyük harf ipucu alır',
      (tester) async {
    await pumpForm(tester);

    final field = find.widgetWithText(TextFormField, 'Yayınevi');
    expect(field, findsOneWidget);
    expect(capsOf(tester, field), TextCapitalization.words);
  });

  testWidgets('yazar alanı öneri alanıdır ve büyük harf ipucunu korur',
      (tester) async {
    await pumpForm(tester);

    final autocomplete = find.byType(AuthorAutocompleteField);
    expect(autocomplete, findsOneWidget);
    final field = find.descendant(
      of: autocomplete,
      matching: find.byType(TextFormField),
    );
    expect(capsOf(tester, field.first), TextCapitalization.words);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/utils/text_normalizer.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yazar görünümündeki "Yazarı yeniden adlandır" aksiyonu: yazım
/// birleştirme (Kasim → Kasım) akışının sayfa üzerindeki hali.
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

BookModel seed(
  String id,
  String title, {
  required List<String> authors,
  required String shelf,
}) =>
    BookModel(
      id: id,
      title: title,
      authors: authors,
      shelf: shelf,
      addedAt: DateTime(2026, 1, 1),
    );

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
      seed('b1', 'Benim Adım Kırmızı', authors: ['Kasım'], shelf: 'Roman'),
      seed('b2', 'Simyacı', authors: ['Kasim'], shelf: 'Tarih'),
      seed('b3', 'Dönüşüm', authors: ['Franz Kafka'], shelf: 'Roman'),
    ]);
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

  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  Future<void> openAllBooks(WidgetTester tester) async {
    await tester.tap(find.text('Raflar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-card-all')));
    await tester.pumpAndSettle();
  }

  Future<void> pickAuthor(WidgetTester tester, String author) async {
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text(author),
      ),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('yazar görünümünde adlandırma aksiyonu var, raf görünümünde yok',
      (tester) async {
    await pumpApp(tester);
    await openAllBooks(tester);

    // Raf görünümü: aksiyon yok.
    expect(find.byTooltip('Yazarı yeniden adlandır'), findsNothing);

    await pickAuthor(tester, 'Kasım');

    // Yazar filtresi aktif: aksiyon görünür.
    expect(find.byTooltip('Yazarı yeniden adlandır'), findsOneWidget);
  });

  testWidgets('yeniden adlandırma kitapları ve filtreyi günceller',
      (tester) async {
    await pumpApp(tester);
    await openAllBooks(tester);
    await pickAuthor(tester, 'Kasım');

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Kasım')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Yazarı yeniden adlandır'));
    await tester.pumpAndSettle();

    // Diyalog varyant yazımı gösterir.
    expect(find.text('• Kasim'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'M. Kasım',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Başlık yeni ada döner; bilgi balonu kitap sayısını verir.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('M. Kasım')),
      findsOneWidget,
    );
    expect(
      find.text('2 kitap "M. Kasım" olarak yazıldı.'),
      findsOneWidget,
    );

    // Filtre yeni adın anahtarına taşındı: iki kitap da listede kalır.
    expect(controller.authorFilter.value, TextNormalizer.searchKey('M. Kasım'));
    expect(find.text('Benim Adım Kırmızı'), findsOneWidget);
    expect(find.text('Simyacı'), findsOneWidget);

    // Depoya yazıldı.
    expect(repository.store.firstWhere((b) => b.id == 'b1').authors,
        ['M. Kasım']);
    expect(repository.store.firstWhere((b) => b.id == 'b2').authors,
        ['M. Kasım']);

    await drainSnackbars(tester);
  });

  testWidgets('boş yazar adı kaydetmez', (tester) async {
    await pumpApp(tester);
    await openAllBooks(tester);
    await pickAuthor(tester, 'Kasım');

    await tester.tap(find.byTooltip('Yazarı yeniden adlandır'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '   ',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Diyalog hata mesajıyla açık kalır; kitaplar değişmez.
    expect(find.text('Yazar adı boş olamaz'), findsOneWidget);
    expect(repository.store.firstWhere((b) => b.id == 'b1').authors, ['Kasım']);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 'Yazarlar' sekmesi: grid görünümü, yazarın kitaplarına geçiş ve
/// yazım birleştirme (yeniden adlandırma) akışı.
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
  String shelf = '',
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
      seed('b1', 'Kasım Kitabı A', authors: ['Kasım']),
      seed('b2', 'Kasım Kitabı B', authors: ['Kasim']),
      seed('b3', 'Kasım Kitabı C', authors: ['Kasim', 'Orhan Pamuk']),
      seed('b4', 'Başka Kitap', authors: ['Ayşe Kulin'], shelf: 'Roman'),
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
    await tester.tap(find.text('Yazarlar').hitTestable());
    await tester.pumpAndSettle();
  }

  /// Snackbar'ın otomatik kapanma zamanlayıcısını tüketir; yoksa
  /// "Timer is still pending" hatası sonraki testleri bozar.
  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('yazarlar gridview de kitap sayısıyla listelenir',
      (tester) async {
    await pumpApp(tester);

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Yazarlar')),
      findsOneWidget,
    );
    // "Kasım" ve "Kasim" tek kartta: 4 kitabın 3'ü Kasım grubunda.
    // hitTestable: IndexedStack'teki kapalı sekmelerde benzer metinler olabilir.
    expect(find.text('Kasım').hitTestable(), findsOneWidget);
    expect(find.text('3 kitap').hitTestable(), findsOneWidget);
    expect(find.text('Ayşe Kulin').hitTestable(), findsOneWidget);
    // Ayşe Kulin ve Orhan Pamuk kartları 1'er kitap taşır.
    expect(find.text('1 kitap').hitTestable(), findsNWidgets(2));
    // Yan yazar ayrı karttır.
    expect(find.text('Orhan Pamuk').hitTestable(), findsOneWidget);
  });

  testWidgets('karta dokununca yazarın kitapları açılır', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Kasım').hitTestable());
    await tester.pumpAndSettle();

    // Başlık yazar adı; kitaplar yazar filtresiyle listelenir.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Kasım')),
      findsOneWidget,
    );
    expect(find.text('Kasım Kitabı A'), findsOneWidget);
    expect(find.text('Kasım Kitabı B'), findsOneWidget);
    expect(find.text('Kasım Kitabı C'), findsOneWidget);
    expect(find.text('Başka Kitap'), findsNothing);
  });

  testWidgets('basılı tutunca yazımlar birleştirilir (Kasim → Kasım)',
      (tester) async {
    await pumpApp(tester);

    await tester.longPress(find.text('Kasım').hitTestable());
    await tester.pumpAndSettle();

    // Diyalog: varyant yazımı görünür.
    expect(find.text('Yazar adını değiştir'), findsOneWidget);
    expect(find.text('• Kasim'), findsOneWidget);
    expect(find.text('3 kitabın yazar bilgisi güncellenecek.'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Kasım',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Bileşke ad aynı olduğundan hiçbir kitap yazılmaz, bilgi balonu çıkmaz.
    expect(find.text('Yazar güncellendi'), findsNothing);
  });

  testWidgets('yeni isimle kayıtta tüm kitaplar güncellenir', (tester) async {
    await pumpApp(tester);

    await tester.longPress(find.text('Kasım').hitTestable());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'M. Kasım',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Bilgi balonu + grid güncel kart.
    expect(find.text('Yazar güncellendi'), findsOneWidget);
    expect(find.text('M. Kasım'), findsOneWidget);
    expect(find.text('Kasım'), findsNothing);

    // Depoya yazıldı: b2'nin Open Library yazımı da değişti.
    expect(repository.store.firstWhere((b) => b.id == 'b2').authors,
        ['M. Kasım']);
    expect(repository.store.firstWhere((b) => b.id == 'b1').authors,
        ['M. Kasım']);
    expect(
      repository.store.firstWhere((b) => b.id == 'b3').authors,
      ['M. Kasım', 'Orhan Pamuk'],
    );

    await drainSnackbars(tester);
  });

  testWidgets('kitaplık boşken yönlendirme mesajı gösterilir', (tester) async {
    // setUp'ın doldurduğu kitaplığı boş bir kurulumla değiştir.
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    final emptyRepo = FakeBookRepository();
    final emptyController = Get.put<LibraryController>(
      LibraryController(emptyRepo, onNotify: (_, __) {}),
      permanent: true,
    );
    await emptyController.loadBooks();

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yazarlar').hitTestable());
    await tester.pumpAndSettle();

    // Raflar sekmesinde (offstage) aynı metin olduğu için hitTestable.
    expect(
      find.text('Kitaplığın boş.\nİlk kitabını ana sayfadan ekle.')
          .hitTestable(),
      findsOneWidget,
    );
  });
}

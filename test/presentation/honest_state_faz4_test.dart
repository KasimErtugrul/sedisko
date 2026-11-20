import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/home_page.dart';
import 'package:kitaplik/presentation/pages/settings_page.dart';
import 'package:kitaplik/presentation/widgets/home/home_empty_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keşke 3, 4 ve 41 (1.23.0) — "Verini koru, dürüst anlat" FAZ 4'ün
/// dürüst yüzler:
///
/// - Keşke 3: boş kitaplık yazısı barkod kullanılabilirliğini izler —
///   "Yazıyı okudum, barkod düğmesini aradım; düğme yoktu."
/// - Keşke 4: yönlendirme yazı değil basılabilir düğmedir — "Bana bir
///   yeri söylüyorsanız, o yere götüren düğmeyi de koyun."
/// - Keşke 41: yedek paylaş açıklaması gerçekte yedeklenen her şeyi
///   sayar — kitaplar, raf tanımları, ödünç kayıtları, satın alma listesi.
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
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });

  testWidgets('barkod ayarı kapalıyken boş durum "elle ekle" der',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    Get.find<SettingsController>().setShowScanActions(false);

    var addTapped = false;
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: HomeEmptyState(
            hasBooks: false,
            onAdd: () => addTapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Kitaplığın boş.\nİlk kitabını elle ekleyebilirsin.'),
      findsOneWidget,
    );
    expect(
      find.text('Kitaplığın boş.\nİlk kitabını barkod tarayarak ekle.'),
      findsNothing,
    );

    // Keşke 4: yazı düğmedir — dokununca ekle menüsü açılır.
    await tester.tap(find.text('Kitap ekle'));
    expect(addTapped, isTrue);
  });

  testWidgets('barkodu desteklemeyen platformda boş durum "elle ekle" der',
      (tester) async {
    // Ayarlar denetleyicisi kayıtsız: karar platform desteğinden gelir.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: HomeEmptyState(
            hasBooks: false,
            // onAdd verilmedi: düğme de çizilmez (arama boşluğu gibi).
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Kitaplığın boş.\nİlk kitabını elle ekleyebilirsin.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('empty-add-book')), findsNothing);

    // Test çerçevesi foundation debug değişkeninin test bitiminde
    // sıfırlanmasını zorlar (kalan tearDown geç kalır).
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('boş kitaplıkta Kitap ekle düğmesi ekle menüsünü açar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: HomeEmptyState(
            hasBooks: false,
            onAdd: () {}, // gerçek menü ana sayfa testindedir
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Barkod kullanılabilirken orijinal vaat aynen durur; düğme aynı adı
    // taşır (aynı iş, aynı ad — keşke 21'in dersi).
    expect(
      find.text('Kitaplığın boş.\nİlk kitabını barkod tarayarak ekle.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('empty-add-book')), findsOneWidget);
    expect(find.text('Kitap ekle'), findsOneWidget);
  });

  testWidgets('Favori yazarlar ipucu kartı Raflar sekmesine giden düğme taşır',
      (tester) async {
    Get.put<LibraryController>(
      LibraryController(
        FakeBookRepository(initial: [
          BookModel(
            id: 'b1',
            title: 'Dune',
            addedAt: DateTime(2026, 1, 1),
          ),
        ]),
        onNotify: (_, __) {},
      ),
      permanent: true,
    );

    // Uzun akış tek ekrana sığsın: ipucu kartı tembel kurulum dışında
    // kalsın (scrollUntilVisible şeritlerin yatay Scrollable'larıyla
    // karışır; büyük yüzey yeterlidir).
    tester.view.physicalSize = const Size(400, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var shelvesOpened = false;
    await tester.pumpWidget(
      GetMaterialApp(
        home: HomePage(onOpenShelves: () => shelvesOpened = true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Raflar sekmesine git'), findsOneWidget);
    await tester.tap(find.text('Raflar sekmesine git'));
    expect(shelvesOpened, isTrue);
  });

  testWidgets('yedek paylaş açıklaması yedeklenen her şeyi sayar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );

    // Ayarlar listesi uzundur; yedekleme bölümü ekran altında kalmasın.
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(home: const SettingsPage()),
    );
    await tester.pumpAndSettle();

    // Keşke 41: zarf formatVersion 2'dir — ödünç kayıtları ve satın alma
    // listesi de yedeğin içindedir; açıklama bunu baştan söyler.
    expect(
      find.text(
        'Kitaplar, raf tanımları, ödünç kayıtları ve satın alma listesi '
        'tek dosyada. Paylaşım menüsünden alıcıyı (örn. WhatsApp) seçin.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Tüm kitaplar ve raf tanımları'),
      findsNothing,
    );
  });
}

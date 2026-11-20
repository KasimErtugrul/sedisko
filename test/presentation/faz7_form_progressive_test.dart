import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/services/book_photo_picker.dart';
import 'package:kitaplik/data/services/cover_photo_store.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/book_form_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:kitaplik/presentation/routes/route_args.dart';
import 'package:kitaplik/presentation/utils/haber_seridi.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keşke 7 + 10 (1.26.0): formun yeni yüzü.
///
/// - Keşke 7: "İlk kez kitap ekleyen birine adı ve raftaki yeri yeter;
///   gerisini sonra da sorabilirsiniz." — temel alanlar üstte, öteki alanlar
///   katlanabilir 'Diğer bilgiler' bölümünde (temiz yeni kitapta KAPALI,
///   düzenlemede ve getirilen veride AÇIK), Kaydet alt barda her an görünür.
/// - Keşke 10: "'Kaydedildi' balonu çıkıp gitti. Kitabım ana sayfada göze
///   çarpmadı" — şerit kitabın GİTTİĞİ YERİ söyler.
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
    // '/' kabuğu (IndexedStack) Ayarlar sekmesini de kurar: tercih
    // denetleyicisi şart.
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(SettingsController(prefs: prefs));
    Get.put<BookRepository>(FakeBookRepository(), permanent: true);
    Get.put<LibraryController>(
      LibraryController(Get.find<BookRepository>(), onNotify: (_, __) {}),
      permanent: true,
    );
    // Form rotasının bağlamı fotoğraf deposu ve seçiciyi ister.
    Get.put<CoverPhotoStore>(CoverPhotoStore(), permanent: true);
    Get.put<BookPhotoPicker>(
      ImagePickerBookPhotoPicker(),
      permanent: true,
    );
  });

  tearDown(() {
    Get.reset();
    kaldirHaberSeridi();
  });

  /// Formu rota üzerinden açar: gerçek akışta denetleyici rotanın
  /// bağlamında Get.arguments'tan BookFormArgs okur (bkz. Routes.form).
  Future<void> openForm(
    WidgetTester tester, {
    BookModel? book,
    bool isEdit = false,
  }) async {
    // Form alanları ('Diğer bilgiler' bölümü dahil) tek ekrana sığsın:
    // ListView tembel kurulumuna takılmasın.
    tester.view.physicalSize = const Size(400, 2600);
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
      arguments: BookFormArgs(book: book, isEdit: isEdit),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('keşke 7: temiz yeni kitapta ayrıntılar KAPALI, Kaydet görünür',
      (tester) async {
    await openForm(tester, book: BookModel.blank());

    // Temel alanlar üstte görünür.
    expect(find.text('Kitap adı *'), findsOneWidget);
    expect(find.text('Raf'), findsOneWidget);
    expect(find.byKey(const ValueKey('form-chip-rafsiz')), findsOneWidget);

    // Kaydet alt barda: form sayfasında, kaydırmaya gerek yok.
    expect(find.byKey(const ValueKey('form-save')), findsOneWidget);

    // Ayrıntı alanları katlıyken ekranda kurulmaz.
    expect(find.text('Basım yılı'), findsNothing);
    expect(find.text('Yayınevi'), findsNothing);
    expect(find.text('Diğer bilgiler (isteğe bağlı)'), findsOneWidget);
  });

  testWidgets('keşke 7: ayrıntı alanı dolu gelen kitapta bölüm AÇIK gelir',
      (tester) async {
    final fetched = BookModel.blank()
        .copyWith(
          title: 'Simyacı',
          pageCount: 188,
          publisher: 'Can Yayınları',
        );
    await openForm(tester, book: fetched);

    // Getirilen veri görünmez kalmaz: bölüm kendiliğinden açılır.
    expect(find.text('Sayfa sayısı'), findsOneWidget);
    expect(find.text('Yayınevi'), findsOneWidget);
    expect(find.text('Okuma durumu'), findsOneWidget);
  });

  testWidgets('keşke 7: düzenleme bölümü AÇIK gelir', (tester) async {
    final existing = BookModel(
      id: 'b1',
      title: 'Dune',
      addedAt: DateTime(2026, 1, 1),
    );
    await openForm(tester, book: existing, isEdit: true);

    expect(find.text('Kitabı düzenle'), findsOneWidget);
    expect(find.text('Sayfa sayısı'), findsOneWidget);
    expect(find.text('Okuma durumu'), findsOneWidget);
  });

  testWidgets('keşke 10: yeni kayıt şeridi gittiği yeri söyler (raflı)',
      (tester) async {
    await openForm(tester, book: BookModel.blank());

    final form = Get.find<BookFormController>();
    form.titleCtrl.text = 'Simyacı';
    form.shelfCtrl.text = 'Salon - 2. raf';
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('form-save')));
    await tester.pumpAndSettle();

    expect(find.text('Kaydedildi'), findsOneWidget);
    // Şeridin içindeki mesaj: form alanındaki aynı metinle çakışmasın diye
    // şerit kökünden ararız.
    final serit = find.byKey(const ValueKey('haber-seridi'));
    expect(
      find.descendant(of: serit, matching: find.textContaining('"Salon - 2. raf" rafında')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: serit, matching: find.textContaining('Bütün kitaplar Raflar sekmesinde')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('keşke 10: rafsız yeni kayıt "Rafsız" ve yeri söyler',
      (tester) async {
    await openForm(tester, book: BookModel.blank());

    final form = Get.find<BookFormController>();
    form.titleCtrl.text = 'Hacı Baba';
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('form-save')));
    await tester.pumpAndSettle();

    expect(find.text('Kaydedildi'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('haber-seridi')),
        matching: find.textContaining('(rafsız)'),
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('keşke 10: düzenlemede şerit yalnız kitabın adını söyler',
      (tester) async {
    final existing = BookModel(
      id: 'b1',
      title: 'Eski Kitap',
      addedAt: DateTime(2026, 1, 1),
    );
    await openForm(tester, book: existing, isEdit: true);

    final form = Get.find<BookFormController>();
    form.titleCtrl.text = 'Eski Kitap (2. baskı)';
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('form-save')));
    await tester.pumpAndSettle();

    expect(find.text('Kaydedildi'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('haber-seridi')),
        matching: find.text('Eski Kitap (2. baskı)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('haber-seridi')),
        matching: find.textContaining('Raflar sekmesinde'),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 1));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/book_form_controller.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/pages/book_form_page.dart';

/// Keşke 8 + 12 (1.23.0) — "Verini koru, dürüst anlat" FAZ 4'ün form
/// yüzü:
///
/// - Keşke 8: "Zorunlu alana ne yazacağımı bilemedim, bir şey uydurdum;
///   sonra raflarımda uydurma bir isim çıktı." Raf zorunluluğu kalktı:
///   boş bırakılan kitap Rafsız kartında görünür; formda 'Rafsız' çipi
///   tek dokunuşla boşaltır.
/// - Keşke 12: "Yanlışlıkla harf yazdım; uygulama sessizce kabul etti."
///   Basım yılı artık yalnız sayı kabul eder (sayfa sayısıyla aynı tutum).
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
    Get.reset();
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    List<BookModel> seed = const [],
  }) async {
    // Form bitirme hedefi alanıyla uzadı; çipler de ekranda kalsın diye
    // tek ekrana sığacak kadar yüksek yüzey kullanılır (ListView tembel
    // kurulumu ekran altındakileri kurmaz).
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repository = FakeBookRepository(initial: seed);
    final library = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    Get.put<BookFormController>(
      BookFormController(repository, library),
      permanent: true,
    );
    await tester.pumpWidget(
      GetMaterialApp(home: Scaffold(appBar: AppBar(title: const Text('Liste')))),
    );
    await tester.pumpAndSettle();
    // Get.to'nun geleceği rota kapanınca tamamlanır; await edilmez —
    // yoksa test gövdesi pop'ı sonsuza dek bekler.
    Get.to(() => const BookFormPage());
    await tester.pumpAndSettle();
  }

  testWidgets('formda Rafsız çipi var; raf boş kaydedilince kitap Rafsız olur',
      (tester) async {
    await pumpForm(
      tester,
      seed: [
        BookModel(
          id: 's1',
          title: 'Raf dolu',
          shelf: 'Salon',
          addedAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    // Raf artık zorunlu değil: yıldız ve eski hata metni yok; yardım
    // yazısı nedeni söyler. Tanımlı raf çipleri ve Rafsız çipi durur.
    expect(find.text('Raf *'), findsNothing);
    expect(find.text('Raf'), findsOneWidget);
    expect(
      find.text('Rafı belli değilse boş bırak: kitap Rafsız olur'),
      findsOneWidget,
    );
    expect(find.text('Salon'), findsOneWidget);
    expect(find.byKey(const ValueKey('form-chip-rafsiz')), findsOneWidget);

    // Keşke 8 akışı: rafa hiçbir şey yazmadan kaydet.
    final form = Get.find<BookFormController>();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kitap adı *'),
      'Hacı Baba',
    );
    await tester.tap(find.text('Rafsız'));
    expect(form.shelfCtrl.text, isEmpty);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Form kapandı; kitap RAFSIZ kaydedildi (uydurma raf adı yok).
    expect(find.text('Yeni kitap'), findsNothing);
    expect(find.text('Kaydedildi'), findsOneWidget);
    final library = Get.find<LibraryController>();
    final saved = library.books.where((b) => b.title == 'Hacı Baba').single;
    expect(saved.shelf, isEmpty);
    // Tohumlu 'Salon' kitabı durur; Rafsız anahtarı kitaplıkta artık var
    // ('Rafsız' her zaman sonda durur — shelfKeys sözleşmesi).
    expect(library.shelfKeys, ['Salon', 'Rafsız']);

    // Kalan snackbar zamanlayıcısını tüket.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('tanımlı raf çipi dokunulunca raf adı doldurulur (eski davranış)',
      (tester) async {
    await pumpForm(
      tester,
      seed: [
        BookModel(
          id: 's1',
          title: 'Raf dolu',
          shelf: 'Salon',
          addedAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    final form = Get.find<BookFormController>();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kitap adı *'),
      'Simyacı',
    );
    await tester.tap(find.text('Salon'));
    expect(form.shelfCtrl.text, 'Salon');

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final library = Get.find<LibraryController>();
    final saved = library.books.where((b) => b.title == 'Simyacı').single;
    expect(saved.shelf, 'Salon');

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('basım yılı harf kabul etmez ve dört haneyi aşmaz', (tester) async {
    await pumpForm(tester);

    // Keşke 7 (1.26.0): basım yılı 'Diğer bilgiler' bölümünde; temiz yeni
    // kitapta bölüm kapalı gelir, açılır.
    await tester.tap(find.text('Diğer bilgiler (isteğe bağlı)'));
    await tester.pumpAndSettle();

    final form = Get.find<BookFormController>();
    final yearField = find.widgetWithText(TextFormField, 'Basım yılı');

    await tester.enterText(yearField, '19a95');
    expect(form.publishDateCtrl.text, '1995');

    // Yalnız harf girişi ekrana hiçbir şey yazmaz.
    await tester.enterText(yearField, 'abc');
    expect(form.publishDateCtrl.text, isEmpty);

    // Dört haneyi aşan giriş kesilir: '20210' → '2021'. (Alan zaten dört
    // hanedeyken gelen sonraki tuş reddedilir — gerçek klavye davranışı;
    // boş alandan gelen beş haneli giriş ilk dört haneye kesilir.)
    await tester.enterText(yearField, '20210');
    expect(form.publishDateCtrl.text, '2021');

    await tester.enterText(yearField, '');

    // Boş yıl bilinmeyen yıldır; kayıt engellenmez (davranış değişmedi).
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kitap adı *'),
      'Yıllık',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final library = Get.find<LibraryController>();
    expect(library.books.single.title, 'Yıllık');
    expect(library.books.single.publishDate, isNull);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

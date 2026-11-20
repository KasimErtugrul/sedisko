import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/loan_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/borrowed_book_model.dart';
import 'package:kitaplik/data/models/loan_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/loan_controller.dart';
import 'package:kitaplik/presentation/pages/borrowed_page.dart';
import 'package:kitaplik/presentation/pages/loans_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bellek içi sahte repository; FAB'ın kitap seçici tablosu kitaplığı
/// buradan okur (keşke 38 testleri).
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

/// Ödünç sayfaları (1.18.0): LoansPage bölümleri, geri alma ve onaylı
/// silme; BorrowedPage ekleme, düzenleme, geri verme akışları.
void main() {
  late LoanLocalDataSource store;
  late List<String> notifications;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LoanLocalDataSource(prefs);
    notifications = [];
  });

  tearDown(() {
    Get.reset();
  });

  LoanController putController() {
    return Get.put<LoanController>(
      LoanController(
        store: store,
        onNotify: (title, message) => notifications.add('$title|$message'),
      ),
      permanent: true,
    );
  }

  /// Snackbar'ın otomatik kapanma zamanlayıcısını tüketir; yoksa
  /// "Timer is still pending" hatası sonraki testleri bozar.
  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(GetMaterialApp(home: page));
    await tester.pumpAndSettle();
  }

  group('LoansPage', () {
    testWidgets('bölümleri kartları ve alt metni gösterir; aktifler en yeni önce',
        (tester) async {
      await store.upsertLoan(LoanModel(
        id: 'eski',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ali',
        lentAt: DateTime(2026, 1, 15),
      ));
      await store.upsertLoan(LoanModel(
        id: 'yeni',
        bookId: 'b2',
        bookTitle: 'Sefiller',
        person: 'Veli',
        lentAt: DateTime(2026, 2, 20),
        note: '2 haftada getirecek',
      ));
      await store.upsertLoan(LoanModel(
        id: 'geri',
        bookId: 'b3',
        bookTitle: 'Şeker Portakalı',
        person: 'Zeynep',
        lentAt: DateTime(2025, 12, 1),
        returnedAt: DateTime(2025, 12, 20),
      ));
      putController();

      await pumpPage(tester, const LoansPage());

      expect(find.text('Ödünç verilenler'), findsOneWidget);
      expect(find.text('Sürüyor'), findsOneWidget);
      expect(find.text('Geri alınanlar'), findsOneWidget);
      expect(find.text('Dune'), findsOneWidget);
      expect(find.text('Sefiller'), findsOneWidget);
      expect(find.text('Şeker Portakalı'), findsOneWidget);
      expect(find.textContaining('verildi: 20.02.2026'), findsOneWidget);
      expect(find.textContaining('2 haftada getirecek'), findsOneWidget);
      expect(find.textContaining('geri alındı: 20.12.2025'), findsOneWidget);
      expect(
        find.text(
          'Sağ alttaki "Ödünç ver" düğmesiyle ya da kitap detayından '
          'yeni kayıt açılır.',
        ),
        findsOneWidget,
      );

      // Kart sırası: yeni, eski, geri alınan.
      final cardKeys = tester
          .widgetList<Card>(find.byType(Card))
          .map((c) => (c.key as ValueKey<String>).value)
          .toList();
      expect(cardKeys, ['loan-card-yeni', 'loan-card-eski', 'loan-card-geri']);
    });

    testWidgets('Geri alındı düğmesi kaydı geri alınanlara taşır',
        (tester) async {
      await store.upsertLoan(LoanModel(
        id: 'l1',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ali',
        lentAt: DateTime(2026, 1, 15),
      ));
      putController();

      await pumpPage(tester, const LoansPage());

      await tester.tap(find.text('Geri alındı'));
      await tester.pumpAndSettle();
      await drainSnackbars(tester);

      // Kayıt geri alınanlar bölümünde; düğme artık yok.
      expect(find.text('Geri alınanlar'), findsOneWidget);
      expect(find.text('Sürüyor'), findsNothing);
      expect(find.textContaining('geri alındı:'), findsOneWidget);
      expect(find.text('Geri alındı'), findsNothing);
      await drainSnackbars(tester);
    });

    testWidgets('basılı tutunca onaylı silme yapar', (tester) async {
      await store.upsertLoan(LoanModel(
        id: 'l1',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ali',
        lentAt: DateTime(2026, 1, 15),
      ));
      putController();

      await pumpPage(tester, const LoansPage());

      await tester.longPress(find.byKey(const ValueKey('loan-card-l1')));
      await tester.pumpAndSettle();

      expect(find.text('Kayıt silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(find.text('Dune'), findsNothing);
      expect(store.getLoans(), isEmpty);
    });

    testWidgets('keşke 37: görünür sil düğmesi aynı onayı açar',
        (tester) async {
      await store.upsertLoan(LoanModel(
        id: 'eski',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ali',
        lentAt: DateTime(2026, 1, 15),
      ));
      putController();

      await pumpPage(tester, const LoansPage());

      // Silme artık kartın ucunda görünür bir düğme; basılı tutmayı
      // keşfetmeyi gerektirmez.
      await tester.tap(find.byKey(const ValueKey('loan-delete-eski')));
      await tester.pumpAndSettle();

      expect(find.text('Kayıt silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(find.text('Dune'), findsNothing);
      expect(store.getLoans(), isEmpty);
    });

    testWidgets('keşke 38: Ödünç ver düğmesi kitap seçtirip kişi '
        'diyaloğunu açar', (tester) async {
      final library = Get.put<LibraryController>(
        LibraryController(
          FakeBookRepository(initial: [
            BookModel(id: 'b1', title: 'Dune', addedAt: DateTime(2026, 1, 1)),
          ]),
          onNotify: (_, __) {},
        ),
        permanent: true,
      );
      await library.loadBooks();
      putController();

      await pumpPage(tester, const LoansPage());

      await tester.tap(find.byKey(const Key('loans-add-fab')));
      await tester.pumpAndSettle();

      // Seçici tablosu kitaplığı listeler.
      expect(
        find.text('Kimi ödünç vereceksin? Önce kitabı seç.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('lend-pick-b1')));
      await tester.pumpAndSettle();

      // Kişi diyaloğu: kişi yazılınca onay aktifleşir; kayıt yazılır.
      expect(find.byKey(const Key('lend-person-field')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('lend-person-field')),
        'Ayşe',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Ödünç ver'));
      await tester.pumpAndSettle();
      await drainSnackbars(tester);

      expect(store.getLoans(), hasLength(1));
      expect(store.getLoans().single.person, 'Ayşe');
      // Kart sayfada görünür; sürüyor bölümünde listelenir.
      expect(find.text('Sürüyor'), findsOneWidget);
    });

    testWidgets('keşke 38: verilecek kitap kalmadıysa seçici açılmaz',
        (tester) async {
      final library = Get.put<LibraryController>(
        LibraryController(FakeBookRepository(), onNotify: (_, __) {}),
        permanent: true,
      );
      await library.loadBooks();
      putController();

      await pumpPage(tester, const LoansPage());

      await tester.tap(find.byKey(const Key('loans-add-fab')));
      await tester.pumpAndSettle();

      // Kitaplık boş: sessiz tablo yerine açıkça söyleyilir.
      expect(
        find.textContaining('Ödünç verilecek kitap yok'),
        findsOneWidget,
      );
      expect(
        find.text('Kimi ödünç vereceksin? Önce kitabı seç.'),
        findsNothing,
      );
      await drainSnackbars(tester);
    });

    testWidgets('kayıt yokken boş durum mesajı gösterilir', (tester) async {
      putController();

      await pumpPage(tester, const LoansPage());

      expect(
        find.text(
          'Henüz ödünç verilen kitap yok.\n'
          'Sağ alttaki "Ödünç ver" düğmesini kullanabilirsin.',
        ),
        findsOneWidget,
      );
    });
  });

  group('BorrowedPage', () {
    testWidgets('FAB ile alıntı ekler', (tester) async {
      putController();

      await pumpPage(tester, const BorrowedPage());

      await tester.tap(find.byKey(const Key('borrowed-add-fab')));
      await tester.pumpAndSettle();
      expect(find.text('Ödünç al'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('borrowed-title-field')),
        'Sefiller',
      );
      await tester.enterText(
        find.byKey(const Key('borrowed-authors-field')),
        'Victor Hugo',
      );
      await tester.enterText(
        find.byKey(const Key('borrowed-owner-field')),
        'Ali',
      );
      // ValueListenableBuilder'a bağlı onay düğmesi bir karede aktifleşir.
      await tester.pump();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Sefiller'), findsOneWidget);
      expect(find.textContaining('Sahibi: Ali'), findsOneWidget);
      expect(find.text('Victor Hugo'), findsOneWidget);
      expect(find.text('Sürüyor'), findsOneWidget);
      // Depoya yazıldı.
      expect(store.getBorrowed(), hasLength(1));
    });

    testWidgets('karta dokununca düzenleme diyaloğu açılır ve yazar',
        (tester) async {
      await store.upsertBorrowed(BorrowedBookModel(
        id: 'bb1',
        title: 'Sefiller',
        authors: ['Victor Hugo'],
        owner: 'Ali',
        borrowedAt: DateTime(2026, 2, 10),
      ));
      putController();

      await pumpPage(tester, const BorrowedPage());

      await tester.tap(find.byKey(const ValueKey('borrowed-card-bb1')));
      await tester.pumpAndSettle();

      expect(find.text('Ödünç düzenle'), findsOneWidget);
      // Alanlar mevcut değerlerle dolu gelir.
      expect(
        tester.widget<TextField>(
          find.byKey(const Key('borrowed-title-field')),
        ).controller!.text,
        'Sefiller',
      );
      expect(
        tester.widget<TextField>(
          find.byKey(const Key('borrowed-owner-field')),
        ).controller!.text,
        'Ali',
      );

      await tester.enterText(
        find.byKey(const Key('borrowed-title-field')),
        'Sefiller (2. baskı)',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(find.text('Sefiller (2. baskı)'), findsOneWidget);
      expect(find.text('Sefiller'), findsNothing);
      expect(store.getBorrowed().single.title, 'Sefiller (2. baskı)');
    });

    testWidgets('Geri verdim kaydı geri verilenlere taşır', (tester) async {
      await store.upsertBorrowed(BorrowedBookModel(
        id: 'bb1',
        title: 'Sefiller',
        owner: 'Ali',
        borrowedAt: DateTime(2026, 2, 10),
      ));
      putController();

      await pumpPage(tester, const BorrowedPage());

      await tester.tap(find.text('Geri verdim'));
      await tester.pumpAndSettle();
      await drainSnackbars(tester);

      expect(find.text('Geri verilenler'), findsOneWidget);
      expect(find.text('Sürüyor'), findsNothing);
      expect(find.textContaining('geri verildi:'), findsOneWidget);
      expect(find.text('Geri verdim'), findsNothing);
      await drainSnackbars(tester);
    });

    testWidgets('basılı tutunca onaylı silme yapar', (tester) async {
      await store.upsertBorrowed(BorrowedBookModel(
        id: 'bb1',
        title: 'Sefiller',
        owner: 'Ali',
        borrowedAt: DateTime(2026, 2, 10),
      ));
      putController();

      await pumpPage(tester, const BorrowedPage());

      await tester.longPress(find.byKey(const ValueKey('borrowed-card-bb1')));
      await tester.pumpAndSettle();

      expect(find.text('Kayıt silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(find.text('Sefiller'), findsNothing);
      expect(store.getBorrowed(), isEmpty);
    });

    testWidgets('keşke 37: görünür sil düğmesi aynı onayı açar',
        (tester) async {
      await store.upsertBorrowed(BorrowedBookModel(
        id: 'bb2',
        title: 'Şeker Portakalı',
        owner: 'Veli',
        borrowedAt: DateTime(2026, 3, 1),
      ));
      putController();

      await pumpPage(tester, const BorrowedPage());

      await tester.tap(find.byKey(const ValueKey('borrowed-delete-bb2')));
      await tester.pumpAndSettle();

      expect(find.text('Kayıt silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      expect(find.text('Şeker Portakalı'), findsNothing);
      expect(store.getBorrowed(), isEmpty);
    });

    testWidgets('kayıt yokken boş durum mesajı gösterilir', (tester) async {
      putController();

      await pumpPage(tester, const BorrowedPage());

      expect(
        find.text(
          'Henüz başkasından ödünç aldığın kitap yok.\n'
          'Sağ alttaki düğmeyle ekleyebilirsin.',
        ),
        findsOneWidget,
      );
    });
  });
}

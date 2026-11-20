import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/loan_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/loan_controller.dart';
import 'package:kitaplik/presentation/pages/book_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bellek içi sahte repository; ağ/depoya dokunmaz.
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

/// Kitap detay sayfasının ödünç akışı (1.18.0): "Ödünç ver" aksiyonu,
/// diyalogdan banner'a, banner'dan geri almaya. LoanController'sız
/// kurulumda aksiyon/banner hiç çizilmez (mevcut testler bozulmaz).
void main() {
  late LoanLocalDataSource store;
  late LoanController loanController;
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

  BookModel seedBook() => BookModel(
        id: 'b1',
        title: 'Dune',
        addedAt: DateTime(2026, 1, 1),
      );

  LibraryController putLibrary() {
    final library = Get.put<LibraryController>(
      LibraryController(
        FakeBookRepository(initial: [seedBook()]),
        onNotify: (_, __) {},
      ),
      permanent: true,
    );
    return library;
  }

  LoanController putLoan() {
    loanController = Get.put<LoanController>(
      LoanController(
        store: store,
        onNotify: (title, message) => notifications.add('$title|$message'),
      ),
      permanent: true,
    );
    return loanController;
  }

  /// Snackbar'ın otomatik kapanma zamanlayıcısını tüketir; yoksa
  /// "Timer is still pending" hatası sonraki testleri bozar.
  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const BookDetailPage(bookId: 'b1')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'ödünç ver aksiyonu görünür; diyalogla banner açılır, geri alınca kapanır',
      (tester) async {
    putLibrary();
    final controller = putLoan();

    await pumpDetail(tester);

    // Aksiyon görünür; aktif ödünç yokken banner yok. Keşke 30 (1.20.0):
    // eylemler üst çubukta yazısız ikon değil, yazılı şeritte durur.
    expect(find.byTooltip('Ödünç ver'), findsOneWidget);
    expect(find.byKey(const Key('detail-action-lend')), findsOneWidget);
    expect(find.text('Favorilere ekle'), findsOneWidget);
    expect(find.text('Düzenle'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);
    expect(find.byKey(const Key('loan-banner')), findsNothing);

    await tester.tap(find.byTooltip('Ödünç ver'));
    await tester.pumpAndSettle();

    // Diyalog: başlık ve onay düğmesi. Şeritteki etiketle birlikte
    // "Ödünç ver" yazısı üç yerde görünür (şerit + diyalog başlığı + onay).
    expect(find.text('Ödünç ver'), findsNWidgets(3));
    // Kişi boşken onay düğmesi pasiftir.
    expect(
      tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ödünç ver'),
      ).onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('lend-person-field')),
      'Ayşe',
    );
    await tester.pump();
    expect(
      tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ödünç ver'),
      ).onPressed,
      isNotNull,
    );
    await tester.enterText(find.byKey(const Key('lend-note-field')), '3 gün');
    await tester.tap(find.widgetWithText(FilledButton, 'Ödünç ver'));
    await tester.pumpAndSettle();

    // Banner: kişi + tarih + Geri alındı; aksiyon gizlenir; kayıt yazıldı.
    expect(find.byKey(const Key('loan-banner')), findsOneWidget);
    expect(find.text('Ayşe'), findsOneWidget);
    expect(find.textContaining('verildi:'), findsOneWidget);
    expect(find.textContaining('3 gün'), findsOneWidget);
    expect(find.byTooltip('Ödünç ver'), findsNothing);
    expect(controller.loans, hasLength(1));
    expect(controller.loans.single.isActive, isTrue);
    expect(store.getLoans(), hasLength(1));

    await drainSnackbars(tester);

    // Geri alındı → banner kaybolur, aksiyon geri gelir.
    await tester.tap(find.text('Geri alındı'));
    await tester.pumpAndSettle();
    await drainSnackbars(tester);

    expect(find.byKey(const Key('loan-banner')), findsNothing);
    expect(find.byTooltip('Ödünç ver'), findsOneWidget);
    expect(controller.loans.single.isActive, isFalse);
  });

  testWidgets('LoanController yokken ödünç aksiyonu ve banner çizilmez',
      (tester) async {
    putLibrary();

    await pumpDetail(tester);

    expect(find.byTooltip('Ödünç ver'), findsNothing);
    expect(find.byKey(const Key('loan-banner')), findsNothing);
    // Sayfanın kalanı eskisi gibi çalışır.
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Raf'), findsOneWidget);
  });
}

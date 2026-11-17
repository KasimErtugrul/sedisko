import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/domain/services/book_sort.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sıralama alt sayfası: yön segmenti + alan seçimi + liste güncellemesi.
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
  late LibraryController controller;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    // Şeritleri (favori/okunuyor/not) boş tut: her başlık listede tek olsun
    // ki widget sırası koordinatla doğrulanabilsin.
    repository = FakeBookRepository(initial: [
      BookModel(
        id: 'b1',
        title: 'Dune',
        shelf: 'Roman',
        pageCount: 412,
        publisher: 'Can Yayınları',
        addedAt: DateTime(2026, 1, 1),
      ),
      BookModel(
        id: 'b2',
        title: 'Simyacı',
        shelf: 'Roman',
        pageCount: 184,
        publisher: 'Yapı Kredi',
        addedAt: DateTime(2026, 1, 2),
      ),
      BookModel(
        id: 'b3',
        title: 'Dönüşüm',
        shelf: 'Bilim',
        pageCount: 96,
        publisher: 'Can Yayınları',
        addedAt: DateTime(2026, 1, 3),
      ),
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

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(home: const HomePage()));
    await tester.pumpAndSettle();
  }

  Future<void> openSortSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Sırala'));
    await tester.pumpAndSettle();
    expect(find.text('Kitapları sırala'), findsOneWidget);
  }

  testWidgets('yön değişimi sayfayı kapatmaz, alan seçince kapanır ve liste '
      'güncellenir', (tester) async {
    await pumpHome(tester);
    await openSortSheet(tester);

    // Azalan'a bas: sayfa açık kalır, yön kaydedilir.
    await tester.tap(find.text('Azalan'));
    await tester.pumpAndSettle();
    expect(controller.sortAscending.value, isFalse);
    expect(find.text('Kitapları sırala'), findsOneWidget);

    // Alan seç: sayfa kapanır, alan + yön birleşik uygulanır.
    await tester.tap(find.text('Sayfa sayısı'));
    await tester.pumpAndSettle();

    expect(find.text('Kitapları sırala'), findsNothing);
    expect(controller.sortField.value, BookSortField.pageCount);
    expect(controller.sortAscending.value, isFalse);
    expect(controller.hasCustomSort, isTrue);

    // 'Tüm kitaplar' listesi sayfa sayısı azalan dizilir: 412 > 184 > 96.
    final dune = tester.getTopLeft(find.text('Dune')).dy;
    final simyaci = tester.getTopLeft(find.text('Simyacı')).dy;
    final donusum = tester.getTopLeft(find.text('Dönüşüm')).dy;
    expect(dune, lessThan(simyaci));
    expect(simyaci, lessThan(donusum));
  });

  testWidgets('yayınevi artan sıralama aynı grupta ada göre kırılır',
      (tester) async {
    await pumpHome(tester);
    await openSortSheet(tester);

    await tester.tap(find.text('Yayınevi'));
    await tester.pumpAndSettle();

    expect(controller.sortField.value, BookSortField.publisher);
    expect(controller.sortAscending.value, isTrue);

    // Can Yayınları (Dönüşüm, Dune) < Yapı Kredi (Simyacı); Can grubunda
    // eşitlik kitap adına kırılır: Dönüşüm (ö) < Dune (u).
    final donusum = tester.getTopLeft(find.text('Dönüşüm')).dy;
    final dune = tester.getTopLeft(find.text('Dune')).dy;
    final simyaci = tester.getTopLeft(find.text('Simyacı')).dy;
    expect(donusum, lessThan(dune));
    expect(dune, lessThan(simyaci));
  });

  testWidgets('varsayılan görünüm kitap adı artandır ve rozet yoktur',
      (tester) async {
    await pumpHome(tester);

    // Kitap adı artan: Dönüşüm < Dune < Simyacı.
    final donusum = tester.getTopLeft(find.text('Dönüşüm')).dy;
    final dune = tester.getTopLeft(find.text('Dune')).dy;
    final simyaci = tester.getTopLeft(find.text('Simyacı')).dy;
    expect(donusum, lessThan(dune));
    expect(dune, lessThan(simyaci));

    expect(controller.hasCustomSort, isFalse);
  });
}

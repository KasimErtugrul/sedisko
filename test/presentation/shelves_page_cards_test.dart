import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/shelves_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raflar sekmesi zengin raf kartları: raf adı + kitap sayısı + okunuyor
/// ve bitti kırılımı. Kullanıcı isteğiyle kartlar yalnız ad/sayısını değil
/// rafın okuma durumunu da tek bakışta gösterir.
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

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      BookModel(
        id: 's1',
        title: 'Okunan roman',
        shelf: 'Roman',
        status: ReadingStatus.reading,
        addedAt: DateTime(2026, 1, 1),
      ),
      BookModel(
        id: 's2',
        title: 'Biten roman',
        shelf: 'Roman',
        status: ReadingStatus.finished,
        addedAt: DateTime(2026, 1, 1),
      ),
      BookModel(
        id: 's3',
        title: 'Dokunulmamış',
        shelf: 'Roman',
        addedAt: DateTime(2026, 1, 1),
      ),
      BookModel(
        id: 's4',
        title: 'Rafsız okunan',
        shelf: '',
        status: ReadingStatus.reading,
        addedAt: DateTime(2026, 1, 1),
      ),
    ]);
    final controller = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await controller.loadBooks();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpShelves(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(home: const ShelvesPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('raf kartında kitap sayısı ve okunuyor/bitti kırılımı vardır',
      (tester) async {
    await pumpShelves(tester);

    const roman = ValueKey('shelf-card-Roman');
    expect(
      find.descendant(of: find.byKey(roman), matching: find.text('3 kitap')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(roman),
        matching: find.text('1 okunuyor'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(roman), matching: find.text('1 bitti')),
      findsOneWidget,
    );
  });

  testWidgets('rafsız kartta yalnız dolu kırılımlar gösterilir',
      (tester) async {
    await pumpShelves(tester);

    const rafsiz = ValueKey('shelf-card-Rafsız');
    expect(
      find.descendant(of: find.byKey(rafsiz), matching: find.text('1 kitap')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(rafsiz),
        matching: find.text('1 okunuyor'),
      ),
      findsOneWidget,
    );
    // Rafsızda bitmiş kitap yok: bitti satırı yer tutmaz.
    expect(
      find.descendant(of: find.byKey(rafsiz), matching: find.text('0 bitti')),
      findsNothing,
    );
  });

  testWidgets("'Tüm kitaplar' kartı kitaplığın genel kırılımını verir",
      (tester) async {
    await pumpShelves(tester);

    const all = ValueKey('shelf-card-all');
    expect(
      find.descendant(of: find.byKey(all), matching: find.text('4 kitap')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(all),
        matching: find.text('2 okunuyor'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(all), matching: find.text('1 bitti')),
      findsOneWidget,
    );
  });

  testWidgets('raf kartları grid görünümünde iki kolona yerleşir',
      (tester) async {
    // Kullanıcı isteği (1.16.0): "raflar bottom navigator'ünde rafları
    // grid view ile görelim." Kartlar artık yatay şerit değil, grid
    // hücreleridir: 'Tüm kitaplar' ve 'Roman' aynı satırda, 'Roman'
    // ikinci kolondadır.
    await pumpShelves(tester);

    expect(find.byType(GridView), findsOneWidget);

    final all = tester.getTopLeft(find.byKey(const ValueKey('shelf-card-all')));
    final roman =
        tester.getTopLeft(find.byKey(const ValueKey('shelf-card-Roman')));
    final rafsiz =
        tester.getTopLeft(find.byKey(const ValueKey('shelf-card-Rafsız')));

    expect(roman.dy, all.dy, reason: 'ilk satırda iki kart yan yana');
    expect(roman.dx, greaterThan(all.dx), reason: 'Roman ikinci kolonda');
    expect(rafsiz.dy, greaterThan(all.dy), reason: 'Rafsız ikinci satırda');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bellek içi sahte repository; kitaplar doğrudan store ile beslenir.
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

BookModel seed({
  required String id,
  required String title,
  bool favorite = false,
  String notes = '',
  ReadingStatus status = ReadingStatus.notStarted,
}) {
  return BookModel(
    id: id,
    title: title,
    shelf: 'Raf',
    addedAt: DateTime(2026, 1, 1),
    isFavorite: favorite,
    notes: notes.isEmpty ? null : notes,
    status: status,
    startedAt: status == ReadingStatus.notStarted ? null : DateTime(2026, 1, 2),
  );
}

void main() {
  late FakeBookRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      seed(id: 'b1', title: 'Simyacı', favorite: true),
      seed(
        id: 'b2',
        title: 'Şeker Portakalı',
        status: ReadingStatus.reading,
        notes: 'Bölüm özetleri burada',
      ),
      seed(id: 'b3', title: 'Dönüşüm', notes: 'Gregor hikâyesi'),
      seed(id: 'b4', title: 'Hayvan Çiftliği', status: ReadingStatus.finished),
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

  Future<void> pumpHome(WidgetTester tester) async {
    // Uzun akışı tek ekranda kurmak için test yüzeyi yüksek tutulur; böylece
    // sanallaştırılmış listenin alt bölümleri de ağaçta kurulur.
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(home: const HomePage()));
    await tester.pumpAndSettle();
  }

  testWidgets('özet satırı ve tüm kitaplar listesi görünür', (tester) async {
    await pumpHome(tester);

    expect(find.text('Toplam'), findsOneWidget);
    expect(find.text('Okunuyor'), findsOneWidget);
    expect(find.text('Bitti'), findsOneWidget);
    // 'Simyacı' favoriler şeridinde, 'Tüm kitaplar' listesinde de vardır.
    expect(find.text('Simyacı'), findsWidgets);
    expect(find.text('Tüm kitaplar'), findsOneWidget);
    expect(find.text('Hayvan Çiftliği'), findsOneWidget);
  });

  testWidgets('dolu bölümler başlık ve yatay şerit gösterir', (tester) async {
    await pumpHome(tester);

    expect(find.text('Devam eden kitaplar'), findsOneWidget);
    expect(find.text('Favoriler'), findsOneWidget);
    expect(find.text('Not aldıkların'), findsOneWidget);

    // Favori kapak kartında kalp rozeti vardır.
    expect(find.byIcon(Icons.favorite), findsWidgets);
  });

  testWidgets('dolu olmayan bölümler listeye girmez', (tester) async {
    // Favori, okunuyor ve notlu kitapları sil; yalnız bitmiş kitap kalsın.
    await Get.find<LibraryController>().deleteBook('b1');
    await Get.find<LibraryController>().deleteBook('b2');
    await Get.find<LibraryController>().deleteBook('b3');

    await pumpHome(tester);

    expect(find.text('Devam eden kitaplar'), findsNothing);
    expect(find.text('Favoriler'), findsNothing);
    expect(find.text('Not aldıkların'), findsNothing);
    expect(find.text('Tüm kitaplar'), findsOneWidget);
    expect(find.text('Hayvan Çiftliği'), findsOneWidget);
  });

  testWidgets('arama yazılınca bölümler yerine sonuç listesi çıkar',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('Favoriler'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'simyacı');
    await tester.pumpAndSettle();

    expect(find.text('Favoriler'), findsNothing);
    expect(find.text('Devam eden kitaplar'), findsNothing);
    expect(find.text('Simyacı'), findsOneWidget);
    expect(find.text('Dönüşüm'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Hepsi'), findsOneWidget);
  });

  testWidgets('boş kitaplıkta yönlendirici boş durum gösterilir',
      (tester) async {
    repository.store.clear();
    await Get.find<LibraryController>().loadBooks();

    await pumpHome(tester);

    expect(
      find.text('Kitaplığın boş.\nİlk kitabını barkod tarayarak ekle.'),
      findsOneWidget,
    );
  });
}

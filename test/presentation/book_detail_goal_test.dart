import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/services/book_photo_picker.dart';
import 'package:kitaplik/data/services/cover_photo_store.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detay sayfası bitirme hedefi göstergeleri: kalan gün + günlük sayfa
/// planı, gecikme uyarısı ve bitmiş kitapta hedefe göre sonuç.
///
/// Hedef tarihler çalışma anında DateTime.now()'a göre kurulur; gün
/// karşılaştırmaları takvim günü bazlı olduğu için test günün hangi
/// saatinde çalıştırılırsa çalıştırılsın aynı metinleri üretir.
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
    repository = FakeBookRepository(initial: [
      // Okunuyor + hedef: bugün 10 gün sonrası, kalan 200 sayfa.
      BookModel(
        id: 'g1',
        title: 'Hedefli kitap',
        shelf: 'Raf A',
        status: ReadingStatus.reading,
        pageCount: 300,
        currentPage: 100,
        startedAt: DateTime(2026, 1, 5),
        addedAt: DateTime(2026, 1, 1),
        targetFinishDate: DateTime.now().add(const Duration(days: 10)),
      ),
      // Hedefi geçmiş okunuyor kitap.
      BookModel(
        id: 'g2',
        title: 'Geciken kitap',
        shelf: 'Raf A',
        status: ReadingStatus.reading,
        pageCount: 300,
        currentPage: 50,
        startedAt: DateTime(2026, 1, 5),
        addedAt: DateTime(2026, 1, 1),
        targetFinishDate: DateTime.now().subtract(const Duration(days: 4)),
      ),
      // Bitmiş + hedef: 2026-01-06 bitti, hedef 2026-01-10 → 4 gün önce.
      BookModel(
        id: 'g3',
        title: 'Erken biten',
        shelf: 'Raf B',
        status: ReadingStatus.finished,
        finishedAt: DateTime(2026, 1, 6),
        addedAt: DateTime(2025, 12, 1),
        targetFinishDate: DateTime(2026, 1, 10),
      ),
      // Hedefsiz kitap: hedef satırları hiç görünmez.
      BookModel(
        id: 'g4',
        title: 'Hedefsiz kitap',
        shelf: 'Raf B',
        addedAt: DateTime(2026, 1, 1),
      ),
    ]);
    Get.put<BookRepository>(repository, permanent: true);
    Get.put<CoverPhotoStore>(CoverPhotoStore(), permanent: true);
    Get.put<BookPhotoPicker>(ImagePickerBookPhotoPicker(), permanent: true);
    controller = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await controller.loadBooks();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpDetail(WidgetTester tester, String bookId) async {
    // Detay sayfası uzun; tüm kartlar tek ekranda görünsün diye test
    // yüzeyi yüksek tutulur.
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
    Get.toNamed(Routes.detail, arguments: bookId);
    await tester.pumpAndSettle();
  }

  testWidgets('okunuyor kitapta hedef, kalan gün ve günlük plan görünür',
      (tester) async {
    await pumpDetail(tester, 'g1');

    expect(find.textContaining('Bitirme hedefi:'), findsOneWidget);
    expect(find.textContaining('10 gün kaldı'), findsOneWidget);
    // 200 kalan sayfa / 10 gün = 20.
    expect(
      find.textContaining('günde ~20 sayfa okumalısın'),
      findsOneWidget,
    );
  });

  testWidgets('hedefi geçen kitapta gecikme hat rengiyle uyarılır',
      (tester) async {
    await pumpDetail(tester, 'g2');

    expect(find.textContaining('4 gün gecikti'), findsOneWidget);
    expect(find.textContaining('günde ~'), findsNothing); // plan üretilmez
  });

  testWidgets('bitmiş kitapta hedefe göre sonuç gösterilir', (tester) async {
    await pumpDetail(tester, 'g3');

    expect(find.textContaining('hedefinden 4 gün önce bitirdin'), findsOneWidget);
  });

  testWidgets('hedefsiz kitapta hedef satırı çizilmez', (tester) async {
    await pumpDetail(tester, 'g4');

    expect(find.textContaining('Bitirme hedefi'), findsNothing);
  });
}

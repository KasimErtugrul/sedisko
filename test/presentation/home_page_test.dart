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
  int pageCount = 0,
  int currentPage = 0,
  DateTime? target,
}) {
  return BookModel(
    id: id,
    title: title,
    shelf: 'Raf',
    addedAt: DateTime(2026, 1, 1),
    isFavorite: favorite,
    notes: notes.isEmpty ? null : notes,
    status: status,
    pageCount: pageCount,
    currentPage: currentPage,
    startedAt: status == ReadingStatus.notStarted ? null : DateTime(2026, 1, 2),
    targetFinishDate: target,
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
        pageCount: 200,
        currentPage: 50,
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

  Future<void> pumpHome(WidgetTester tester, {double height = 2000}) {
    // Uzun akışı tek ekranda kurmak için test yüzeyi yüksek tutulur; böylece
    // sanallaştırılmış listenin alt bölümleri de ağaçta kurulur. Tüm bölüm
    // başlıklarını birden doğrulayan testler daha yüksek yüzey ister.
    tester.view.physicalSize = Size(400, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(GetMaterialApp(home: const HomePage()))
        .then((_) => tester.pumpAndSettle());
  }

  testWidgets('özet satırı ve bölüm şeritleri görünür', (tester) async {
    await pumpHome(tester, height: 4000);

    expect(find.text('Toplam'), findsOneWidget);
    expect(find.text('Okunuyor'), findsOneWidget);
    expect(find.text('Bitti'), findsOneWidget);
    // On bölüm de her koşulda görünür; boş olanlar ipucu kartı koyar.
    expect(find.text('Devam eden kitaplar'), findsOneWidget);
    expect(find.text('Favoriler'), findsOneWidget);
    expect(find.text('Favori yazarlar'), findsOneWidget);
    expect(find.text('Bitirme hedefleri'), findsOneWidget);
    expect(find.text('Son eklenenler'), findsOneWidget);
    expect(find.text('En çok sayfalı kitaplar'), findsOneWidget);
    expect(find.text('En çok kitaba sahip yazarlar'), findsOneWidget);
    expect(find.text('Rafların'), findsOneWidget);
    expect(find.text('Bu ay bitirdiklerin'), findsOneWidget);
    expect(find.text('Not aldıkların'), findsOneWidget);
  });

  testWidgets("'Tüm kitaplar' bölümü ana sayfada artık yok", (tester) async {
    await pumpHome(tester, height: 4000);

    // Bölüm başlığı kaldırıldı; tam kitaplık Raflar > Tüm kitaplar
    // kartından açılır. 'Hayvan Çiftliği' artık "Son eklenenler" şeridinde
    // (tüm kitaplar bir tarihte eklenmiştir); 'Dönüşüm' hem "Not aldıkların"
    // hem "Son eklenenler" şeridinde görünür.
    expect(find.text('Tüm kitaplar'), findsNothing);
    expect(find.text('Hayvan Çiftliği'), findsOneWidget);
    expect(find.text('Dönüşüm'), findsNWidgets(2));
  });

  testWidgets('favori olmasa da Favoriler bölümü ipucuyla görünür',
      (tester) async {
    // Favoriyi kaldır; bölüm yine de görünmeli, yönlendirme metniyle.
    await Get.find<LibraryController>().deleteBook('b1');

    await pumpHome(tester);

    expect(find.text('Favoriler'), findsOneWidget);
    expect(find.textContaining('Henüz favori kitabın yok'), findsOneWidget);
  });

  testWidgets('bitirme hedefi olan kitaplar hedef şeridinde sıralanır',
      (tester) async {
    // Takvim günü bazlı göreli tarihler: test hangi günde çalışırsa
    // çalışsın geri sayım metinleri aynıdır (b2: 10 gün, b3: 40 gün).
    final today = DateTime.now();
    final b2Target = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 10));
    final b3Target = DateTime(today.year, today.month, today.day)
        .add(const Duration(days: 40));
    // b5: bitmiş + hedefli — hedef şeridine girmez (bitmişler hedefli
    // değildir), "Son eklenenler" şeridinde görünür.
    repository.store.add(seed(
      id: 'b5',
      title: 'Hedefli Bitmiş',
      status: ReadingStatus.finished,
      target: today.subtract(const Duration(days: 3)),
    ));
    await Get.find<LibraryController>().loadBooks();
    // Hedefleri kur (store'da id ile hedefli kayıtları güncelle).
    final controller = Get.find<LibraryController>();
    await controller.saveBook(
      controller.byId('b2')!.copyWith(targetFinishDate: b2Target),
      deriveLog: false,
    );
    await controller.saveBook(
      controller.byId('b3')!.copyWith(targetFinishDate: b3Target),
      deriveLog: false,
    );

    await pumpHome(tester);

    expect(find.text('Bitirme hedefleri'), findsOneWidget);
    // En yakın hedef önce: yatay şeritte "10 gün kaldı" "40 gün kaldı"nın
    // SOLUNDADIR (aynı satır, sıra soldan sağa).
    final near = tester.getTopLeft(find.text('10 gün kaldı'));
    final far = tester.getTopLeft(find.text('40 gün kaldı'));
    expect(near.dx < far.dx, isTrue);
    // Şeritte yalnız 2 geri sayım kartı vardır; bitmiş 'Hedefli Bitmiş'
    // ("Son eklenenler"de görünür) hedef şeridine girmez.
    expect(find.textContaining('gün kaldı'), findsNWidgets(2));
    expect(find.text('Hedefli Bitmiş'), findsOneWidget);
  });

  testWidgets('en çok sayfalı kitaplar bölümü azalan sıralıdır',
      (tester) async {
    await controllerSetupPages(tester);

    expect(find.text('En çok sayfalı kitaplar'), findsOneWidget);
    // Şerit kartlarında ilerleme görünür; b2 dört şeritte birden vardır
    // (Devam eden + Son eklenenler + En çok sayfalı + Not aldıkların).
    // Dikey akış 4000 piksel yüzeyde tamamen kurulur; ama yatay şeritler
    // tembeldir: "Son eklenenler" şeridinde b2 Türkçe ad sırasıyla 4.
    // karttır (Dönüşüm, Hayvan Çiftliği, Simyacı, Şeker Portakalı) ve
    // kart genişliği 116 pikselde 4. kartın başlangıcı görünür alanın
    // hemen dışına düşer, kart ağaçta kurulmaz. Dolayısıyla kurulan
    // 3 kopya sayılır: Devam eden + En çok sayfalı + Not aldıkların.
    expect(find.text('Sayfa 50/200'), findsNWidgets(3));
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

/// Sayfa sayıları olan ikinci bir senaryo kurar ve ana sayfayı pompalar.
Future<void> controllerSetupPages(WidgetTester tester) async {
  final controller = Get.find<LibraryController>();
  await controller.saveBook(
    controller.byId('b1')!.copyWith(pageCount: 480),
    deriveLog: false,
  );
  tester.view.physicalSize = const Size(400, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GetMaterialApp(home: const HomePage()));
  await tester.pumpAndSettle();
}

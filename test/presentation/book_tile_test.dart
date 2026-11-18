import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/presentation/widgets/book_tile.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tüm liste kartlarında kullanılan BookTile: kitaba ve rafa ilişkin tüm
/// bilgiler (raf, yayınevi, basım, sayfa sayısı, durum, hedef) tek bakışta
/// görünür — kullanıcı isteği "tüm cardlarda tüm bilgiler olsun".
///
/// CoverImage ağ istekleri olmayan bir widget olduğundan (URL yoksa
/// yer tutucu) sahte ağ kurulmasına gerek yoktur.
void main() {
  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
  });

  tearDown(Get.reset);

  Future<void> pumpTile(WidgetTester tester, BookModel book) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              BookTile(book: book, onTap: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('kartta raf, yayınevi, basım ve sayfa sayısı görünür',
      (tester) async {
    await pumpTile(
      tester,
      BookModel(
        id: 't1',
        title: 'Simyacı',
        authors: ['Paulo Coelho'],
        shelf: 'Salon - 2. raf',
        publisher: 'Can Yayınları',
        publishDate: '2021',
        pageCount: 320,
        addedAt: DateTime(2026, 1, 1),
      ),
    );

    // Meta satırı: raf + yayınevi + basım + sayfa tek satırda birleşir.
    expect(
      find.textContaining('Raf: Salon - 2. raf'),
      findsOneWidget,
    );
    expect(find.textContaining('Can Yayınları'), findsOneWidget);
    expect(find.textContaining('Basım: 2021'), findsOneWidget);
    expect(find.textContaining('320 sayfa'), findsOneWidget);
    expect(find.textContaining('Paulo Coelho'), findsOneWidget);
  });

  testWidgets('rafsız kitapta Rafsız yazar, hedefsiz kitapta hedef satırı yok',
      (tester) async {
    await pumpTile(
      tester,
      BookModel(
        id: 't2',
        title: 'Rafsız kitap',
        addedAt: DateTime(2026, 1, 1),
      ),
    );

    expect(find.text('Rafsız'), findsOneWidget); // meta satırı (başlık değil)
    expect(find.textContaining('Hedef'), findsNothing);
    expect(find.text('Henüz başlanmadı'), findsOneWidget);
  });

  testWidgets('okunuyor kitapta ilerleme ve hedef geri sayımı görünür',
      (tester) async {
    // Bugünden 10 gün sonrasına hedef: kalan sayfa 200, günlük plan 20.
    final target = DateTime.now().add(const Duration(days: 10));
    await pumpTile(
      tester,
      BookModel(
        id: 't3',
        title: 'Devam eden kitap',
        shelf: 'Raf A',
        status: ReadingStatus.reading,
        pageCount: 300,
        currentPage: 100,
        addedAt: DateTime(2026, 1, 1),
        targetFinishDate: target,
      ),
    );

    expect(find.text('Sayfa 100/300 (%33)'), findsOneWidget);
    // "Hedef: dd.mm.yyyy • 10 gün • günde ~20 sayfa" — parçalar halinde doğrula.
    expect(find.textContaining('10 gün'), findsOneWidget);
    expect(find.textContaining('günde ~20 sayfa'), findsOneWidget);
  });

  testWidgets('hedefi geçen kitapta gecikme uyarısı çıkar', (tester) async {
    final past = DateTime.now().subtract(const Duration(days: 3));
    await pumpTile(
      tester,
      BookModel(
        id: 't4',
        title: 'Geciken kitap',
        status: ReadingStatus.reading,
        pageCount: 300,
        currentPage: 100,
        addedAt: DateTime(2026, 1, 1),
        targetFinishDate: past,
      ),
    );

    expect(find.textContaining('3 gün gecikti'), findsOneWidget);
  });

  testWidgets('bitmiş kitapta hedefe göre sonuç görünür', (tester) async {
    final target = DateTime(2026, 1, 10);
    final finished = DateTime(2026, 1, 6);
    await pumpTile(
      tester,
      BookModel(
        id: 't5',
        title: 'Bitmiş kitap',
        status: ReadingStatus.finished,
        finishedAt: finished,
        addedAt: DateTime(2025, 12, 1),
        targetFinishDate: target,
      ),
    );

    expect(find.textContaining('Hedefinden'), findsOneWidget);
    expect(find.textContaining('gün önce bitirdin'), findsOneWidget);
    expect(find.textContaining('Bitti'), findsOneWidget);
  });
}

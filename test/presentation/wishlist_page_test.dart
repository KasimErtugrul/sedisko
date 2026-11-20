import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/wishlist_local_datasource.dart';
import 'package:kitaplik/data/models/wishlist_item_model.dart';
import 'package:kitaplik/presentation/controllers/wishlist_controller.dart';
import 'package:kitaplik/presentation/pages/wishlist_page.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Satın alınacaklar sayfası: listeleme, onaylı silme, elle ekleme ve
/// boş durum (1.18.0).
void main() {
  late SharedPreferences prefs;
  late WishlistController controller;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    controller = Get.put<WishlistController>(
      WishlistController(store: WishlistLocalDataSource(prefs)),
    );
    await controller.load();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpWishlistPage(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.wishlist,
        getPages: [
          GetPage(name: Routes.wishlist, page: () => const WishlistPage()),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  WishlistItemModel openLibraryItem() => WishlistItemModel(
        id: 'w1',
        title: 'Dune',
        authors: ['Frank Herbert'],
        publisher: 'Ace Books',
        pageCount: 412,
        note: 'okurken önerildi',
        addedAt: DateTime(2026, 1, 2),
        source: WishlistSource.openlibrary,
      );

  WishlistItemModel manualItem() => WishlistItemModel(
        id: 'w2',
        title: 'Simyacı',
        authors: ['Paulo Coelho'],
        addedAt: DateTime(2026, 1, 1),
      );

  testWidgets('kayıtlar meta, not ve kaynak rozetiyle listelenir',
      (tester) async {
    await controller.add(openLibraryItem());
    await controller.add(manualItem());
    await pumpWishlistPage(tester);

    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Frank Herbert'), findsOneWidget);
    expect(find.text('Ace Books · 412 s.'), findsOneWidget);
    expect(find.text('Not: okurken önerildi'), findsOneWidget);
    expect(find.text('Open Library'), findsOneWidget); // kaynak rozeti
    expect(find.text('Simyacı'), findsOneWidget);
    expect(find.text('Kendim ekledim'), findsOneWidget); // kaynak rozeti (keşke 5)
    expect(find.text('Kitaplığa ekle'), findsNWidgets(2));
  });

  testWidgets('silme onay diyaloğu çalışır: Vazgeç korur, Çıkar siler',
      (tester) async {
    await controller.add(openLibraryItem());
    await pumpWishlistPage(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('"Dune" listeden çıkarılsın mı?'), findsOneWidget);

    // Vazgeç: kayıt kalır.
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Dune'), findsOneWidget);

    // Çıkar: kayıt listeden ve depodan düşer.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çıkar'));
    await tester.pumpAndSettle();

    expect(find.text('Dune'), findsNothing);
    expect(WishlistLocalDataSource(prefs).getItems(), isEmpty);
  });

  testWidgets('boş durumda yönlendirme metni gösterilir', (tester) async {
    await pumpWishlistPage(tester);

    expect(
      find.text('Henüz satın alınacak kitap yok.\n'
          'Open Library aramasından ya da "Elle ekle" ile ekleyebilirsin.'),
      findsOneWidget,
    );
    expect(find.text('Dune'), findsNothing);
  });

  testWidgets('FAB "Elle ekle" diyaloğuyla kayıt ekler', (tester) async {
    await pumpWishlistPage(tester);

    await tester.tap(find.text('Elle ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Elle ekle'), findsNWidgets(2)); // FAB + diyalog başlığı

    await tester.enterText(
      find.widgetWithText(TextField, 'Kitap adı *'),
      'Yeni Kitap',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Yazar(lar) (virgülle)'),
      'Ayşe Kulin, Ahmet Ümit',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Yeni Kitap'), findsOneWidget);
    expect(find.text('Ayşe Kulin, Ahmet Ümit'), findsOneWidget);
    expect(find.text('Kendim ekledim'), findsOneWidget);
    expect(controller.items.single.title, 'Yeni Kitap');
    expect(controller.items.single.authors, ['Ayşe Kulin', 'Ahmet Ümit']);
    expect(controller.items.single.source, WishlistSource.manual);
  });

  testWidgets('Karta dokununca düzenleme diyaloğu açılır ve kaydı günceller',
      (tester) async {
    await controller.add(openLibraryItem());
    await pumpWishlistPage(tester);

    await tester.tap(find.text('Dune'));
    await tester.pumpAndSettle();

    expect(find.text('Düzenle'), findsOneWidget);
    // Mevcut değerler doldurulmuş gelir.
    expect(find.widgetWithText(TextField, 'Kitap adı *'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Kitap adı *'),
      'Dune (yeniden)',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Not (isteğe bağlı)'),
      '',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.text('Dune (yeniden)'), findsOneWidget);
    expect(find.text('Not: okurken önerildi'), findsNothing);
    expect(controller.items.single.title, 'Dune (yeniden)');
    expect(controller.items.single.note, isNull);
    // ISBN/kaynak gibi diğer alanlar korunur.
    expect(controller.items.single.source, WishlistSource.openlibrary);
    expect(controller.items.single.id, 'w1');
  });

  testWidgets('keşke 36: Aldım işareti onaylı kaydı listeden çıkarır',
      (tester) async {
    await controller.add(openLibraryItem());
    await pumpWishlistPage(tester);

    // Her kartta iki net yol yan yana: Aldım + Kitaplığa ekle.
    expect(find.text('Aldım'), findsOneWidget);
    expect(find.text('Kitaplığa ekle'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wishlist-bought-w1')));
    await tester.pumpAndSettle();

    expect(find.text('"Dune" alındı mı?'), findsOneWidget);

    // Vazgeç: kayıt listede kalır.
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Dune'), findsOneWidget);

    // Evet, aldım: kayıt listeden ve depodan düşer.
    await tester.tap(find.byKey(const ValueKey('wishlist-bought-w1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wishlist-bought-confirm')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(find.text('Dune'), findsNothing);
    expect(WishlistLocalDataSource(prefs).getItems(), isEmpty);
  });
}

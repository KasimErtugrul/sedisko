import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kitaplik/data/datasources/open_library_remote_datasource.dart';
import 'package:kitaplik/data/datasources/wishlist_local_datasource.dart';
import 'package:kitaplik/data/models/wishlist_item_model.dart';
import 'package:kitaplik/presentation/controllers/openlibrary_search_controller.dart';
import 'package:kitaplik/presentation/controllers/wishlist_controller.dart';
import 'package:kitaplik/presentation/pages/search_page.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _ok(List<Map<String, dynamic>> docs) => http.Response(
      jsonEncode({'docs': docs, 'numFound': docs.length}),
      200,
      headers: {'content-type': 'application/json'},
    );

const _duneDoc = <String, dynamic>{
  'key': '/works/OL1',
  'title': 'Dune',
  'author_name': ['Frank Herbert'],
  'first_publish_year': 1965,
  'publisher': ['Chilton Books'],
  'number_of_pages_median': 412,
};

const _madonnaDoc = <String, dynamic>{
  'key': '/works/OL2',
  'title': 'Kürk Mantolu Madonna',
  'author_name': ['Sabahattin Ali'],
  'first_publish_year': 1943,
};

/// Open Library arama sayfası: arama akışı, hata ve boş alan doğrulaması,
/// satın alma listesi aksiyonu (1.18.0).
void main() {
  late OpenLibrarySearchController searchController;

  setUp(() {
    Get.testMode = true;
    searchController = OpenLibrarySearchController(
      OpenLibraryRemoteDataSource(
        MockClient((request) async => _ok([_duneDoc, _madonnaDoc])),
      ),
    );
    Get.put<OpenLibrarySearchController>(searchController);
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpSearchPage(WidgetTester tester) async {
    // Testler arası GetX durum sızıntısına karşı pump öncesi kaydı garanti
    // et. TAZE örnek kur: sızan silme onClose çağırıp eski örneğin metin
    // alanlarını dispose etmiş olabilir.
    if (!Get.isRegistered<OpenLibrarySearchController>()) {
      Get.put<OpenLibrarySearchController>(
        OpenLibrarySearchController(
          OpenLibraryRemoteDataSource(
            MockClient((request) async => _ok([_duneDoc, _madonnaDoc])),
          ),
        ),
      );
    }
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.search,
        getPages: [
          GetPage(name: Routes.search, page: () => const SearchPage()),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Snackbar otomatik kapanma zamanlayıcısını tüketir.
  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('alanlar doldurulup Ara\'ya basınca sonuç kartları gelir',
      (tester) async {
    await pumpSearchPage(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Kitap adı'),
      'Dune',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Yazar'), 'Herbert');
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();

    // Alan metinleri EditableText olarak da 'Dune' içerir; kartı ayrıca
    // hedefleyelim.
    expect(find.widgetWithText(Card, 'Dune'), findsOneWidget);
    expect(find.widgetWithText(Card, 'Kürk Mantolu Madonna'), findsOneWidget);
    expect(find.text('Frank Herbert'), findsOneWidget);
    expect(find.text('1965 · Chilton Books · 412 s.'), findsOneWidget);
    expect(find.text('1943'), findsOneWidget);
  });

  testWidgets('boş alanla aramada hata metni gösterilir', (tester) async {
    await pumpSearchPage(tester);

    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();

    expect(find.text('En az bir alanı doldurun.'), findsOneWidget);
    expect(find.text('Dune'), findsNothing);
    // searched temizlendiği için "Sonuç bulunamadı" görünmez.
    expect(find.text('Sonuç bulunamadı. Farklı sözcüklerle deneyin.'),
        findsNothing);
  });

  testWidgets('ağ hatasında uyarı kartı gösterilir', (tester) async {
    await Get.delete<OpenLibrarySearchController>(force: true);
    Get.put<OpenLibrarySearchController>(
      OpenLibrarySearchController(
        OpenLibraryRemoteDataSource(
          MockClient((request) async => http.Response('boom', 500)),
        ),
      ),
    );
    await pumpSearchPage(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Yazar'), 'Herbert');
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();

    expect(find.text('Sunucu hatası (500)'), findsOneWidget);
    expect(find.text('Dune'), findsNothing);
  });

  testWidgets('WishlistController kayıtlıysa satın alma aksiyonu çalışır',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<WishlistController>(
      WishlistController(store: WishlistLocalDataSource(prefs)),
    );
    await pumpSearchPage(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Kitap adı'), 'Dune');
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();

    await tester
        .tap(find.text('Satın alma listesine ekle').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Satın alma listesine eklendi'), findsOneWidget);
    final wishlist = Get.find<WishlistController>();
    expect(wishlist.items.length, 1);
    expect(wishlist.items.single.title, 'Dune');
    expect(wishlist.items.single.source, WishlistSource.openlibrary);

    await drainSnackbars(tester);
  });

  testWidgets('WishlistController kayıtlı değilse aksiyon gizlenir',
      (tester) async {
    await pumpSearchPage(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Kitap adı'), 'Dune');
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();

    expect(find.text('Kitaplığa ekle'), findsNWidgets(2));
    expect(find.text('Satın alma listesine ekle'), findsNothing);
  });
}

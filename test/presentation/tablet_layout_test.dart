import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:kitaplik/presentation/widgets/home/book_cover_card.dart';
import 'package:kitaplik/presentation/widgets/home/shelf_summary_grid.dart';
import 'package:kitaplik/presentation/widgets/responsive/app_breakpoints.dart';
import 'package:kitaplik/presentation/widgets/responsive/responsive_center.dart';
import 'package:kitaplik/presentation/widgets/book_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'responsive_shell_test.dart' show FakeBookRepository;

/// Tablet/geniş ekran düzen testleri: içerik tavan genişlikle ortalanır,
/// grid'ler genişlikte çok kolona açılır; dar ekranda davranış değişmez.
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
      BookModel(
        id: 'b1',
        title: 'Denizler Altında',
        shelf: 'Roman',
        authors: ['Jules Verne'],
        addedAt: DateTime(2026, 1, 1),
      ),
      BookModel(
        id: 'b2',
        title: 'Kürk Mantolu Madonna',
        shelf: 'Roman',
        authors: ['Sabahattin Ali'],
        addedAt: DateTime(2026, 1, 2),
      ),
      BookModel(
        id: 'b3',
        title: 'Osmanlı Tarihi',
        shelf: 'Tarih',
        addedAt: DateTime(2026, 1, 3),
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

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectTab(WidgetTester tester, String label) async {
    // Hem NavigationBar hem NavigationRail etiketleri Text'tir.
    await tester.tap(find.text(label).hitTestable());
  }

  testWidgets('ResponsiveCenter dar ekranda kısıtlamaz, genişte tavanlar',
      (tester) async {
    // Doğrudan pompa: dar yüzeyde çocuk tam genişlikte, genişte tavana sıkışır.
    Future<double> measure(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: ResponsiveCenter(
              child: SizedBox(
                width: double.infinity,
                child: SizedBox(
                  key: const ValueKey('probe'),
                  height: 10,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byKey(const ValueKey('probe'))).width;
    }

    final narrow = await measure(const Size(400, 800));
    final wide = await measure(const Size(1280, 800));

    expect(narrow, 400);
    expect(wide, AppBreakpoints.contentMax);
  });

  testWidgets('raf kitap listesi geniş ekranda tavan genişlikle ortalanır',
      (tester) async {
    await pumpShell(tester, const Size(1280, 2000));

    await selectTab(tester, 'Raflar');
    await tester.pumpAndSettle();
    // 'Tüm kitaplar' kartı tüm kitaplığı ShelfPage'te açar.
    await tester.tap(find.byKey(const ValueKey('shelf-card-all')).hitTestable());
    await tester.pumpAndSettle();

    final tileWidth = tester.getSize(find.byType(BookTile).first).width;
    // Tavan 720 - ListView yatay dolgusu 24 → kart 696 px.
    expect(tileWidth, lessThan(745));
    expect(tileWidth, greaterThan(600));
  });

  testWidgets('raf kitap listesi dar ekranda tam genişlikte akar',
      (tester) async {
    await pumpShell(tester, const Size(400, 2000));

    // Alt bar üzerinden Raflar sekmesi.
    await tester.tap(find.text('Raflar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-card-all')).hitTestable());
    await tester.pumpAndSettle();

    final tileWidth = tester.getSize(find.byType(BookTile).first).width;
    // 400 - dolgu 24 → 376 px civarı; dar ekranda tavan yoktur.
    expect(tileWidth, lessThan(390));
  });

  testWidgets('ana sayfa raf gridi geniş ekranda çok kolona açılır',
      (tester) async {
    await pumpShell(tester, const Size(1280, 4000));

    // maxCrossAxisExtent 240: 1280 genişlikte kart en fazla 240 px olabilir.
    final cardWidth = tester
        .getSize(find.byKey(const ValueKey('home-shelf-card-Roman')).first)
        .width;
    expect(cardWidth, lessThanOrEqualTo(241));
    expect(find.byType(ShelfSummaryGrid), findsOneWidget);
  });

  testWidgets('ana sayfa şeritleri geniş ekranda da kurulur', (tester) async {
    await pumpShell(tester, const Size(1280, 4000));

    // Yatay şerit kartları genişlikte kaybolmaz; son eklenenler kartı var.
    expect(find.byType(BookCoverCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kitap detayı geniş ekranda okunabilir tavanla ortalanır',
      (tester) async {
    await pumpShell(tester, const Size(1280, 4000));

    await selectTab(tester, 'Raflar');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-card-all')).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BookTile).first.hitTestable());
    await tester.pumpAndSettle();

    // Detay gövdesi tavan 840 ile ortalanır (taşma yok).
    expect(tester.takeException(), isNull);
    final listWidth = tester.getSize(find.byType(ListView).first).width;
    expect(listWidth, lessThanOrEqualTo(841));
  });
}

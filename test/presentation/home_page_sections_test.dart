import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:kitaplik/presentation/widgets/home/author_strip.dart';
import 'package:kitaplik/presentation/widgets/home/shelf_summary_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page_test.dart' show FakeBookRepository;

/// Bellek içi sahte repository; kitaplar doğrudan store ile beslenir.
/// (FakeBookRepository home_page_test.dart'tan alınır.)

BookModel seedBook({
  required String id,
  required String title,
  required String shelf,
  List<String> authors = const [],
  required DateTime addedAt,
  ReadingStatus status = ReadingStatus.notStarted,
  DateTime? finishedAt,
}) {
  return BookModel(
    id: id,
    title: title,
    authors: authors,
    shelf: shelf,
    addedAt: addedAt,
    status: status,
    finishedAt: finishedAt,
  );
}

void main() {
  late FakeBookRepository repository;
  late SharedPreferences prefs;
  late DateTime now;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    now = DateTime.now();

    // Bölüm senaryosu:
    // - Orhan Pamuk 3 kitapta (a1, a3, a4), Kasım grubu 2 kitapta
    //   (a2 "Kasım" + a3 "Kasim" yazımı).
    // - Raflar: Roman 2, Tarih 2, rafsız 2.
    // - a5 bu ay bitirildi; a6 geçen ay (32 gün önce) bitirildi.
    repository = FakeBookRepository(initial: [
      seedBook(
        id: 'a1',
        title: 'Deneme Kitap A',
        shelf: 'Roman',
        authors: ['Orhan Pamuk'],
        addedAt: now.subtract(const Duration(days: 1)),
      ),
      seedBook(
        id: 'a2',
        title: 'Deneme Kitap B',
        shelf: 'Roman',
        authors: ['Kasım'],
        addedAt: now.subtract(const Duration(days: 2)),
      ),
      seedBook(
        id: 'a3',
        title: 'Deneme Kitap C',
        shelf: 'Tarih',
        authors: ['Kasim', 'Orhan Pamuk'],
        addedAt: now.subtract(const Duration(days: 3)),
      ),
      seedBook(
        id: 'a4',
        title: 'Deneme Kitap D',
        shelf: '',
        authors: ['Orhan Pamuk'],
        addedAt: now.subtract(const Duration(days: 4)),
      ),
      seedBook(
        id: 'a5',
        title: 'Deneme Kitap E',
        shelf: 'Tarih',
        addedAt: now.subtract(const Duration(days: 5)),
        status: ReadingStatus.finished,
        finishedAt: now,
      ),
      seedBook(
        id: 'a6',
        title: 'Deneme Kitap F',
        shelf: '',
        addedAt: now.subtract(const Duration(days: 6)),
        status: ReadingStatus.finished,
        finishedAt: now.subtract(const Duration(days: 32)),
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

  Future<void> pumpShell(WidgetTester tester) async {
    // Tüm bölümler tek ekranda kurulabilsin diye test yüzeyi yüksek tutulur.
    tester.view.physicalSize = const Size(400, 2000);
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

  testWidgets('yeni bölüm başlıkları görünür, boş bölümler yer tutmaz',
      (tester) async {
    await pumpShell(tester);

    expect(find.text('Son eklenenler'), findsOneWidget);
    expect(find.text('En çok kitaba sahip yazarlar'), findsOneWidget);
    expect(find.text('Rafların'), findsOneWidget);
    expect(find.text('Bu ay bitirdiklerin'), findsOneWidget);
    expect(find.text('Favoriler'), findsOneWidget);
    // Okumada olan kitap yok: bölüm listeye girmez, yer tutmaz.
    expect(find.text('Devam eden kitaplar'), findsNothing);
  });

  testWidgets('son eklenenler şeridi en yeni kitabı başta tutar',
      (tester) async {
    await pumpShell(tester);

    // addedAt azalan: a1 en yeni → solda. Yatay şerit yalnız görünür
    // kartları kurduğu için (test ortamında cache yok) karşılaştırma ilk
    // üç kartla yapılır: a1 < a2 < a3.
    final dxA = tester.getTopLeft(find.text('Deneme Kitap A')).dx;
    final dxB = tester.getTopLeft(find.text('Deneme Kitap B')).dx;
    final dxC = tester.getTopLeft(find.text('Deneme Kitap C')).dx;

    expect(dxA < dxB, isTrue, reason: 'a1 (en yeni) a2\u2019den solda');
    expect(dxB < dxC, isTrue, reason: 'a2 a3\u2019ten solda');
  });

  testWidgets('yazar şeridi kitap sayısına göre sıralar ve yazımları tek kartta toplar',
      (tester) async {
    await pumpShell(tester);

    final strip = find.byType(AuthorStrip);
    expect(
      find.descendant(of: strip, matching: find.text('Orhan Pamuk')),
      findsOneWidget,
    );
    // "Kasim" ve "Kasım" tek kartta: yalnız ilk görülen yazım görünür.
    expect(
      find.descendant(of: strip, matching: find.text('Kasım')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('Kasim')),
      findsNothing,
    );
    expect(
      find.descendant(of: strip, matching: find.text('3 kitap')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('2 kitap')),
      findsOneWidget,
    );

    // Orhan Pamuk (3 kitap) en çok kitaba sahip: şeridin başında. Yazar adı
    // kapak kartlarında da geçtiği için karşılaştırma şeride scope'lanır.
    final dxOrhan = tester
        .getTopLeft(find.descendant(of: strip, matching: find.text('Orhan Pamuk')))
        .dx;
    final dxKasim = tester
        .getTopLeft(find.descendant(of: strip, matching: find.text('Kasım')))
        .dx;
    expect(dxOrhan < dxKasim, isTrue, reason: 'çok kitaplı yazar solda');
  });

  testWidgets('yazar kartına dokununca yazarın kitapları açılır',
      (tester) async {
    await pumpShell(tester);

    await tester
        .tap(find.byKey(const ValueKey('home-author-orhan pamuk')));
    await tester.pumpAndSettle();

    // Raf sayfası yazar adıyla açılır; yalnız Orhan Pamuk kitapları var.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Orhan Pamuk')),
      findsOneWidget,
    );
    expect(find.text('Deneme Kitap A').hitTestable(), findsOneWidget);
    expect(find.text('Deneme Kitap C').hitTestable(), findsOneWidget);
    expect(find.text('Deneme Kitap D').hitTestable(), findsOneWidget);
    // Kasım kitabı listede yok.
    expect(find.text('Deneme Kitap B').hitTestable(), findsNothing);
  });

  testWidgets('rafların gridi iki kolonlu raf kartları gösterir ve raf açar',
      (tester) async {
    await pumpShell(tester);

    final grid = find.byType(ShelfSummaryGrid);
    expect(find.descendant(of: grid, matching: find.text('Roman')),
        findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('Tarih')),
        findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('Rafsız')),
        findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-shelf-card-Roman')),
        matching: find.text('2 kitap'),
      ),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const ValueKey('home-shelf-card-Roman')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Roman')),
      findsOneWidget,
    );
    expect(find.text('Deneme Kitap A').hitTestable(), findsOneWidget);
    expect(find.text('Deneme Kitap B').hitTestable(), findsOneWidget);
    // Tarih kitabı bu rafta yok.
    expect(find.text('Deneme Kitap C').hitTestable(), findsNothing);
  });

  testWidgets("'Tümü' aksiyonu yazarlar sekmesine geçirir", (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const ValueKey('see-all-authors')));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Yazarlar'))
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets("'Tümü' aksiyonu raflar sekmesine geçirir", (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byKey(const ValueKey('see-all-shelves')));
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
    expect(find.byKey(const ValueKey('shelf-card-all')).hitTestable(),
        findsOneWidget);
  });

  testWidgets('bu ay bitirilenler şeritte yer alır', (tester) async {
    // Yatay şeritler yalnız görünür kartları kurduğu için kitaplığı iki
    // kitaba indir: şeritteki her kart ağaçta olsun.
    final controller = Get.find<LibraryController>();
    for (final id in ['a1', 'a2', 'a3', 'a4']) {
      await controller.deleteBook(id);
    }

    await pumpShell(tester);

    expect(find.text('Bu ay bitirdiklerin'), findsOneWidget);
    // a5 hem "Son eklenenler" hem "Bu ay bitirdiklerin" şeridinde.
    expect(find.text('Deneme Kitap E'), findsNWidgets(2));
    // a6 geçen ay bitirildi: bu ay şeridine girmez.
    expect(find.text('Deneme Kitap F'), findsOneWidget);
  });

  testWidgets('geçen ay bitirilen kitap bu ay şeridine girmez', (tester) async {
    // a5'i geçen aya taşı; şerit kartlarının kurulması için kitaplığı
    // iki kitaba indir.
    final controller = Get.find<LibraryController>();
    for (final id in ['a1', 'a2', 'a3', 'a4']) {
      await controller.deleteBook(id);
    }
    await controller.saveBook(
      controller.byId('a5')!.copyWith(
            finishedAt: now.subtract(const Duration(days: 32)),
          ),
      deriveLog: false,
    );

    await pumpShell(tester);

    expect(find.text('Bu ay bitirdiklerin'), findsNothing);
    // Yalnız "Son eklenenler" şeridinde.
    expect(find.text('Deneme Kitap E'), findsOneWidget);
    expect(find.text('Deneme Kitap F'), findsOneWidget);
  });
}

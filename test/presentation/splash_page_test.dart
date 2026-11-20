import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/main.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/splash_page.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Açılış karşılama ekranı ('sedişko', 1.25.0).
///
/// Kullanıcının dileği: "yaaa bir de splash ekran yap be gülüm...
/// sedişko yazsın ama :)". Dört kural test edilir:
/// - açılışta 'sedişko' yazar, altında 'Kitaplığım' durur;
/// - bekletme süresi dolunca ana sayfaya geçilir ve karşılama
///   yığından SİLİNİR (geri tuşu buraya döndürmez);
/// - 'sedişko' temanın tohum rengiyle boyanır (palet/karanlık mod
///   seçimi otomatik izlenir);
/// - 1.3 yazı ölçeğinde (en büyük kademe) ekran taşmaz — hiçbir ekran
///   kendi ölçeğini görmezden gelemez.
void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpOnSplash(WidgetTester tester,
      {double textScale = 1.0}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    if (textScale != 1.0) {
      Get.find<SettingsController>().setTextScale(textScale);
    }
    await tester.pumpWidget(KitaplikApp(prefs: prefs));
  }

  Future<void> crossSplash(WidgetTester tester) async {
    await tester.pump(SplashPage.defaultHoldDuration + SplashPage.fadeDuration);
    await tester.pumpAndSettle();
  }

  testWidgets("açılışta 'sedişko' yazar, altında 'Kitaplığım' durur",
      (tester) async {
    await pumpOnSplash(tester);

    expect(Get.currentRoute, Routes.splash);
    expect(find.text('sedişko'), findsOneWidget);
    expect(find.text('Kitaplığım'), findsOneWidget); // karşılama alt yazısı
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });

  testWidgets('bekletme süresi dolunca ana sayfaya geçer; karşılama '
      'yığından silinir', (tester) async {
    await pumpOnSplash(tester);
    await crossSplash(tester);

    expect(Get.currentRoute, Routes.home);
    expect(find.text('sedişko'), findsNothing);
    // Ana sayfa gerçekten kuruldu: kabuğun AppBar başlığı 'Kitaplığım'.
    expect(find.text('Kitaplığım'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets("'sedişko' temanın tohum rengiyle boyanır", (tester) async {
    await pumpOnSplash(tester);

    final context = tester.element(find.text('sedişko'));
    final widget = tester.widget<Text>(find.text('sedişko'));
    // Metnin KENDİ stili okunur: default textTheme rengi değil, sayfanın
    // uyguladığı colorScheme.primary savunulur (palet seçimi izlenir).
    expect(widget.style?.color, Theme.of(context).colorScheme.primary);
    expect(widget.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('1.3 yazı ölçeğinde karşılama taşmaz', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpOnSplash(tester, textScale: 1.3);

    expect(tester.takeException(), isNull);
    expect(find.text('sedişko'), findsOneWidget);
    await crossSplash(tester);
    expect(Get.currentRoute, Routes.home);
  });
}

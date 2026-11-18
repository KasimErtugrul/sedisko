import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/constants/app_constants.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late SettingsController controller;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    controller = Get.put(SettingsController(prefs: prefs));
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    // Palet ve yazı boyutu bölümleriyle ayarlar listesi uzadı: tüm
    // bölümlerin ağaçta kurulması için test yüzeyi yüksek tutulur.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('tema ve özellik bölümleri görünür', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Görünüm'), findsOneWidget);
    expect(find.text('Sistem varsayılanı'), findsOneWidget);
    expect(find.text('Aydınlık'), findsOneWidget);
    expect(find.text('Karanlık'), findsOneWidget);
    expect(find.text('Uygulama içi özellikler'), findsOneWidget);
    expect(find.text('Kapak görselleri'), findsOneWidget);
    expect(find.text('Barkod tarama'), findsOneWidget);
    expect(find.text('Titreşimli geri bildirim'), findsOneWidget);
    expect(find.text('Kitaplığım ${AppInfo.version}'), findsOneWidget);
  });

  testWidgets('Karanlık radyosu temayı değiştirir ve kalıcı yazar',
      (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Karanlık'));
    await tester.pumpAndSettle();

    expect(controller.themeMode.value, ThemeMode.dark);
    expect(prefs.getInt('settings_theme_mode'), ThemeMode.dark.index);
  });

  testWidgets('anahtarlar tercihleri değiştirir ve kalıcı yazar',
      (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Kapak görselleri'));
    await tester.pumpAndSettle();
    expect(controller.showCovers.value, isFalse);
    expect(prefs.getBool('settings_show_covers'), isFalse);

    await tester.tap(find.text('Barkod tarama'));
    await tester.pumpAndSettle();
    expect(controller.showScanActions.value, isFalse);
    expect(prefs.getBool('settings_scan_actions'), isFalse);

    await tester.tap(find.text('Titreşimli geri bildirim'));
    await tester.pumpAndSettle();
    expect(controller.hapticsEnabled.value, isFalse);
    expect(prefs.getBool('settings_haptics'), isFalse);

    // Tekrar dokununca eski haline döner.
    await tester.tap(find.text('Kapak görselleri'));
    await tester.pumpAndSettle();
    expect(controller.showCovers.value, isTrue);
    expect(prefs.getBool('settings_show_covers'), isTrue);
  });
}

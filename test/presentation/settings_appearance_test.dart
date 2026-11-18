import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/constants/app_constants.dart';
import 'package:kitaplik/core/theme/app_palette.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Görünüm ayarlarının davranış testleri: palet seçimi, özel renk ve
/// yazı boyutu hem denetleyiciye hem kalıcı depoya yazılmalı; tema
/// seçilen tohum renginden türetilmelidir.
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
    // Palet + yazı boyutu bölümleriyle liste uzadı; tüm swatch ve çiplerin
    // ağaçta kurulması için test yüzeyi yüksek tutulur.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // KitaplikApp'in gerçek akışını taklit et: tohum Rx'i Obx içinde okunur;
    // palet değişince tema BÜTÜN ağaçta yeniden türetilir.
    await tester.pumpWidget(
      Obx(
        () => GetMaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: controller.seedColor),
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('denetleyici: palet ve ölçek', () {
    test('hazır palet seçimi kalıcı yazar', () {
      controller.setPalette('orman');

      expect(controller.paletteId.value, 'orman');
      expect(controller.seedColor, AppPalettes.byId('orman')!.seed);
      expect(prefs.getString(SettingsKeys.paletteId), 'orman');
    });

    test('bilinmeyen palet kimliği yok sayılır', () {
      controller.setPalette('orman');
      controller.setPalette('bozuk');

      expect(controller.paletteId.value, 'orman');
    });

    test('özel renk paleti custom yapar ve kalıcı yazar', () {
      final argb = const Color(0xFF8B4513).value;
      controller.setCustomSeed(argb);

      expect(controller.paletteId.value, AppPalettes.customId);
      expect(controller.customSeed.value, argb);
      expect(controller.seedColor, const Color(0xFF8B4513));
      expect(prefs.getString(SettingsKeys.paletteId), AppPalettes.customId);
      expect(prefs.getInt(SettingsKeys.customSeed), argb);
    });

    test('geçersiz yazı boyutu yok sayılır', () {
      controller.setTextScale(1.2);

      expect(controller.textScale.value, AppPalettes.defaultTextScale);
      expect(prefs.getDouble(SettingsKeys.textScale), isNull);
    });

    test('geçerli yazı boyutu kalıcı yazar', () {
      controller.setTextScale(1.3);

      expect(controller.textScale.value, 1.3);
      expect(controller.textScaler.scale(10), 13.0);
      expect(prefs.getDouble(SettingsKeys.textScale), 1.3);
    });

    test('kaydedilmiş palet ve ölçek açılışta yüklenir', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.paletteId: 'gul',
        SettingsKeys.textScale: 1.15,
        SettingsKeys.customSeed: -5, // negatif = bozuk; yok sayılır
      });
      final stored = await SharedPreferences.getInstance();
      // GetX aynı türde ikinci put'i yok sayar: eski örnek silinmelidir.
      await Get.delete<SettingsController>(force: true);
      final loaded = Get.put(SettingsController(prefs: stored));

      expect(loaded.paletteId.value, 'gul');
      expect(loaded.seedColor, AppPalettes.byId('gul')!.seed);
      expect(loaded.textScale.value, 1.15);
    });

    test('bozuk palet kimliği açılışta varsayılana düşer', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.paletteId: 'yok_boyle',
        SettingsKeys.textScale: 9.9, // geçersiz kademe
      });
      final stored = await SharedPreferences.getInstance();
      await Get.delete<SettingsController>(force: true);
      final loaded = Get.put(SettingsController(prefs: stored));

      expect(loaded.paletteId.value, AppPalettes.defaultId);
      expect(loaded.textScale.value, AppPalettes.defaultTextScale);
    });
  });

  group('arayüz: palet ve ölçek seçimi', () {
    testWidgets('palet swatch seçimi temaya sirayet eder ve kalıcı yazar',
        (tester) async {
      await pumpSettings(tester);

      final expectedPrimary =
          ColorScheme.fromSeed(seedColor: AppPalettes.byId('orman')!.seed)
              .primary;
      await tester.tap(find.byKey(const ValueKey('palette-orman')));
      await tester.pumpAndSettle();

      expect(controller.paletteId.value, 'orman');
      expect(prefs.getString(SettingsKeys.paletteId), 'orman');
      // Tema tüm uygulamada değişti: Material'nun birincil rengi orman
      // tohumundan türemiştir.
      expect(Theme.of(Get.context!).colorScheme.primary, expectedPrimary);
    });

    testWidgets('yazı boyutu çipi ölçeği değiştirir', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const ValueKey('text-scale-1.15')));
      await tester.pumpAndSettle();

      expect(controller.textScale.value, 1.15);
      expect(prefs.getDouble(SettingsKeys.textScale), 1.15);
      expect(controller.textScaler.scale(20), 23.0);
    });

    testWidgets('özel renk diyaloğu tohumu değiştirir ve custom yapar',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const ValueKey('palette-custom')));
      await tester.pumpAndSettle();

      // Diyalog açıldı; kaydırıcılara dokunmadan "Seç"e basılır.
      expect(find.text('Özel renk'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pick-color-confirm')));
      await tester.pumpAndSettle();

      expect(controller.paletteId.value, AppPalettes.customId);
      // ARGB geçerli aralıkta (0..0xFFFFFFFF) ve tam opak tohum olarak
      // çözümlenir.
      expect(
        controller.customSeed.value,
        allOf(greaterThanOrEqualTo(0), lessThanOrEqualTo(0xFFFFFFFF)),
      );
      expect(
        controller.seedColor.alpha,
        255,
        reason: 'seçilen renk tam opak tohum olmalı',
      );
      expect(prefs.getString(SettingsKeys.paletteId), AppPalettes.customId);
      expect(prefs.getInt(SettingsKeys.customSeed), isNotNull);
    });

    testWidgets('swatch seçim durumu görünür işaretlenir', (tester) async {
      await pumpSettings(tester);

      // Varsayılan palet açılışta seçilidir.
      final selected = find.byKey(const ValueKey('palette-varsayilan'));
      expect(selected, findsOneWidget);
      expect(
        find.descendant(of: selected, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
    });
  });
}

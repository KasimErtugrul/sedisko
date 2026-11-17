import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/constants/app_constants.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() {
    Get.reset();
  });

  test('tercihler boşken varsayılanlar kullanılır', () {
    final controller = Get.put(SettingsController(prefs: prefs));

    expect(controller.themeMode.value, ThemeMode.system);
    expect(controller.showCovers.value, isTrue);
    expect(controller.hapticsEnabled.value, isTrue);
    expect(controller.showScanActions.value, isTrue);
  });

  test('kaydedilmiş tercihler açılışta yüklenir', () async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.themeMode: 2, // karanlık
      SettingsKeys.showCovers: false,
      SettingsKeys.haptics: false,
      SettingsKeys.scanActions: false,
    });
    final stored = await SharedPreferences.getInstance();
    final controller = Get.put(SettingsController(prefs: stored));

    expect(controller.themeMode.value, ThemeMode.dark);
    expect(controller.showCovers.value, isFalse);
    expect(controller.hapticsEnabled.value, isFalse);
    expect(controller.showScanActions.value, isFalse);
  });

  test('geçersiz tema indeksi sistem varsayılanına döner', () async {
    SharedPreferences.setMockInitialValues({SettingsKeys.themeMode: 99});
    final stored = await SharedPreferences.getInstance();
    final controller = Get.put(SettingsController(prefs: stored));

    expect(controller.themeMode.value, ThemeMode.system);
  });

  test('setterlar tercihi anında kalıcı yazar', () {
    final controller = Get.put(SettingsController(prefs: prefs));

    controller.setThemeMode(ThemeMode.light);
    expect(controller.themeMode.value, ThemeMode.light);
    expect(prefs.getInt(SettingsKeys.themeMode), ThemeMode.light.index);

    controller.setThemeMode(ThemeMode.dark);
    expect(prefs.getInt(SettingsKeys.themeMode), ThemeMode.dark.index);

    controller.setShowCovers(false);
    expect(controller.showCovers.value, isFalse);
    expect(prefs.getBool(SettingsKeys.showCovers), isFalse);

    controller.setHapticsEnabled(false);
    expect(controller.hapticsEnabled.value, isFalse);
    expect(prefs.getBool(SettingsKeys.haptics), isFalse);

    controller.setShowScanActions(false);
    expect(controller.showScanActions.value, isFalse);
    expect(prefs.getBool(SettingsKeys.scanActions), isFalse);
  });

  test('denetleyici kayıtlı değilken statik yardımcılar açıktır', () {
    // Kayıt yok: varsayılan davranış (kapaklar ve tarama aksiyonları açık).
    expect(SettingsController.coversEnabled, isTrue);
    expect(SettingsController.scanActionsVisible, isTrue);
  });

  test('barkod tercihi statik yardımcıya yansır', () {
    final controller = Get.put(SettingsController(prefs: prefs));
    controller.setShowScanActions(false);

    expect(SettingsController.scanActionsVisible, isFalse);
  });
}

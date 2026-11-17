import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_support.dart';

/// Uygulama genelinde tercihler: tema modu ve uygulama içi özellik anahtarları.
///
/// Tercihler [SharedPreferences]'a anında yazılır. Denetleyici `main()` içinde
/// kalıcı olarak kaydedilir; böylece `GetMaterialApp` ilk kareden itibaren
/// doğru temayı kullanır ve tema değişikliği anında yayılır.
class SettingsController extends GetxController {
  SettingsController({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  /// Sistem / Aydınlık / Karanlık tema tercihi.
  final themeMode = ThemeMode.system.obs;

  /// Kitap kapak görselleri internetten gösterilsin mi?
  final showCovers = true.obs;

  /// Dokunsal geri bildirim (titreşim) açık mı?
  final hapticsEnabled = true.obs;

  /// "Barkod tara" aksiyonları menülerde ve düğmelerde gösterilsin mi?
  final showScanActions = true.obs;

  @override
  void onInit() {
    super.onInit();
    final savedMode = _prefs.getInt(SettingsKeys.themeMode);
    if (savedMode != null &&
        savedMode >= 0 &&
        savedMode < ThemeMode.values.length) {
      themeMode.value = ThemeMode.values[savedMode];
    }
    showCovers.value = _prefs.getBool(SettingsKeys.showCovers) ?? true;
    hapticsEnabled.value = _prefs.getBool(SettingsKeys.haptics) ?? true;
    showScanActions.value = _prefs.getBool(SettingsKeys.scanActions) ?? true;
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
    unawaited(_prefs.setInt(SettingsKeys.themeMode, mode.index));
  }

  void setShowCovers(bool value) {
    showCovers.value = value;
    unawaited(_prefs.setBool(SettingsKeys.showCovers, value));
  }

  void setHapticsEnabled(bool value) {
    hapticsEnabled.value = value;
    unawaited(_prefs.setBool(SettingsKeys.haptics, value));
  }

  void setShowScanActions(bool value) {
    showScanActions.value = value;
    unawaited(_prefs.setBool(SettingsKeys.scanActions, value));
  }

  /// Kapak görselleri etkin mi?
  ///
  /// Ayarlar denetleyicisinin kayıtlı olmadığı izole widget testlerinde
  /// varsayılan (açık) davranış korunur.
  static bool get coversEnabled =>
      !Get.isRegistered<SettingsController>() ||
      Get.find<SettingsController>().showCovers.value;

  /// Tarama aksiyonları hem platform desteği hem kullanıcı tercihiyle
  /// sınırlanır; Windows/Linux'ta zaten gizlidir.
  static bool get scanActionsVisible =>
      PlatformSupport.supportsBarcodeScan &&
      (!Get.isRegistered<SettingsController>() ||
          Get.find<SettingsController>().showScanActions.value);
}

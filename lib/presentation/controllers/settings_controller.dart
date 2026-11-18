import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/platform_support.dart';

/// Uygulama genelinde tercihler: tema modu, renk paleti, yazı boyutu ve
/// uygulama içi özellik anahtarları.
///
/// Tercihler [SharedPreferences]'a anında yazılır. Denetleyici `main()` içinde
/// kalıcı olarak kaydedilir; böylece `GetMaterialApp` ilk kareden itibaren
/// doğru temayı kullanır ve tema değişikliği anında yayılır.
///
/// Renk paleti ve yazı boyutu da aynı disiplinle çalışır: gözlenebilir alanlar
/// (Rx) `GetMaterialApp`'in Obx gövdesinde okunur; değişiklik uygulamadaki
/// BÜTÜN ekranlara koşulsuz sirayet eder (tohum renk + TextScaler).
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

  /// Seçili renk paleti kimliği ('varsayilan', 'orman', …, 'custom').
  final paletteId = AppPalettes.defaultId.obs;

  /// Kullanıcının kendi seçtiği tohum rengi (ARGB int; palet 'custom'
  /// değilken anlamsızdır).
  final customSeed = 0.obs;

  /// Yazı boyutu çarpanı; [AppPalettes.textScales] kademelerinden biri.
  final textScale = AppPalettes.defaultTextScale.obs;

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
    final savedPalette = _prefs.getString(SettingsKeys.paletteId);
    if (savedPalette != null &&
        (AppPalettes.byId(savedPalette) != null ||
            savedPalette == AppPalettes.customId)) {
      paletteId.value = savedPalette;
    }
    final savedSeed = _prefs.getInt(SettingsKeys.customSeed);
    if (savedSeed != null && savedSeed >= 0 && savedSeed <= 0xFFFFFFFF) {
      customSeed.value = savedSeed;
    }
    final savedScale = _prefs.getDouble(SettingsKeys.textScale);
    if (savedScale != null && AppPalettes.isValidTextScale(savedScale)) {
      textScale.value = savedScale;
    }
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

  // ---------- Görünüm: palet + yazı boyutu ----------

  /// Tema tohumu: özel renk ya da hazır palet. `GetMaterialApp` bu değeri
  /// `ColorScheme.fromSeed` ile hem açık hem koyu şemada kullanır.
  Color get seedColor =>
      AppPalettes.resolveSeed(paletteId.value, customSeed.value);

  /// Tüm uygulamaya sirayet eden yazı ölçekleyici; `GetMaterialApp.builder`
  /// bunu `MediaQuery.textScaler` olarak koyar.
  TextScaler get textScaler => TextScaler.linear(textScale.value);

  /// Hazır paleti seçer; 'custom' kimliği buradan seçilemez (özel renk
  /// yalnız [setCustomSeed] ile atanır).
  void setPalette(String id) {
    if (AppPalettes.byId(id) == null) return;
    paletteId.value = id;
    unawaited(_prefs.setString(SettingsKeys.paletteId, id));
  }

  /// Kullanıcının kendi tohum rengini atar ve paleti 'custom' yapar.
  void setCustomSeed(int argb) {
    if (argb < 0 || argb > 0xFFFFFFFF) return; // bozuk değer yok sayılır
    customSeed.value = argb;
    paletteId.value = AppPalettes.customId;
    unawaited(_prefs.setString(SettingsKeys.paletteId, AppPalettes.customId));
    unawaited(_prefs.setInt(SettingsKeys.customSeed, argb));
  }

  /// Yazı boyutu kademelerinden birine geçer; geçersiz değer yok sayılır.
  void setTextScale(double scale) {
    if (!AppPalettes.isValidTextScale(scale)) return;
    textScale.value = scale;
    unawaited(_prefs.setDouble(SettingsKeys.textScale, scale));
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

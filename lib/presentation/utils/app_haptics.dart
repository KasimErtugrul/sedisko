import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';

/// Kullanıcının titreşim tercihine saygı duyan dokunsal geri bildirim.
///
/// Ayarlar denetleyicisinin kayıtlı olmadığı izole widget testlerinde
/// titreşim varsayılan olarak açıktır.
class AppHaptics {
  const AppHaptics._();

  static bool get _enabled =>
      !Get.isRegistered<SettingsController>() ||
      Get.find<SettingsController>().hapticsEnabled.value;

  static void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  static void mediumImpact() {
    if (_enabled) HapticFeedback.mediumImpact();
  }
}

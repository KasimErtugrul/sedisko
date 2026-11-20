/// Okuma hatırlatıcısı denetleyicisi (1.18.0 sürümüyle eklendi).
///
/// Ayarlar sayfasındaki hatırlatıcı bölümünü yönetir: tercihleri
/// [ReadingReminderService] üzerinden yükler/kaydeder ve hatırlatıcı açıkken
/// saat ya da hedef değiştiğinde bildirimi yeniden kurar. Bilgilendirme
/// geri çağrısı ([onNotify]) test edilebilirlik için enjekte edilebilir;
/// verilmezse GetX snackbar gösterilir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../data/services/reading_reminder_service.dart';

/// Hatırlatıcı tercihleri ve zamanlama akışının GetX denetleyicisi.
class ReadingReminderController extends GetxController {
  ReadingReminderController({
    required ReadingReminderService service,
    Future<void> Function()? onOpenDeviceSettings,
    void Function(String title, String message)? onNotify,
  })  : _service = service,
        _openDeviceSettings = onOpenDeviceSettings ?? _defaultOpenSettings,
        _notify = onNotify ?? _defaultNotify;

  final ReadingReminderService _service;

  /// Cihaz ayarlarını açan yol (keşke 39, 1.26.0). Gerçekte
  /// permission_handler'ın openAppSettings'i çağrılır; testler sahte
  /// kaydedici enjekte eder. Çağrı başarısız olsa da uygulama akışı
  /// bozulmaz (eksik plugin sessizce yok sayılır).
  final Future<void> Function() _openDeviceSettings;

  final void Function(String title, String message) _notify;

  /// Anahtar açılamadıysa (izin yok) doğruya döner: ayarlar bölümü
  /// 'Ayarlara git' düğmeli izin satırını gösterir. Başarılı açılışta
  /// temizlenir.
  final showPermissionHint = false.obs;

  static void _defaultNotify(String title, String message) {
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }

  /// Keşke 39 (1.26.0): varsayılan açılış — cihazın uygulama ayarları.
  /// Eklenti olmayan platformda MissingPluginException olabilir; akışı
  /// bozmamak için sessizce yutulur.
  static Future<void> _defaultOpenSettings() async {
    try {
      await ph.openAppSettings();
    } catch (_) {
      // Ayarlar açılamadı; kullanıcı satırı zaten yol söylüyor.
    }
  }

  /// 'Ayarlara git' düğmesinin aksiyonu; testlerde sahteyle değiştirilir.
  Future<void> openDeviceSettings() => _openDeviceSettings();

  /// Hatırlatıcı açık mı?
  final enabled = false.obs;

  /// Hatırlatma saati (0-23).
  final hour = 20.obs;

  /// Hatırlatma dakikası (0-59).
  final minute = 30.obs;

  /// Günlük sayfa hedefi (1-1000).
  final pages = 20.obs;

  /// Aç/kapat akışı sürerken true: çift dokunuşla çift kurulum engellenir.
  final busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Kalıcı tercihleri yükle; bozuk/eksik değerler serviste kırpılır.
    enabled.value = _service.isEnabled;
    hour.value = _service.hour;
    minute.value = _service.minute;
    pages.value = _service.pages;
    // Uygulama güncellenip cihaz yeniden başladığında alarm sıfırlanmış
    // olabilir: açılışta sessizce yeniden kurulur. Kapalıyken servis
    // hiçbir işlem yapmaz.
    unawaited(_service.ensureScheduled());
  }

  /// Anahtarı açar/kapatır.
  ///
  /// `true` gelirse bildirim kurulur; kurulum başarısızsa (örn. izin
  /// verilmedi) kullanıcı bilgilendirilir, hatırlatıcı kapalı kalır ve
  /// 'Ayarlara git' düğmeli izin satırı görünür (keşke 39, 1.26.0:
  /// "O ayarı bulmak benim için bir macera; düğme olsaydı direkt
  /// giderdim"). Başarılı açılışta satır kaybolur.
  Future<void> toggle(bool value) async {
    if (busy.value) return;
    busy.value = true;
    try {
      if (value) {
        final ok = await _service.enable(
          hour: hour.value,
          minute: minute.value,
          pages: pages.value,
        );
        if (ok) {
          enabled.value = true;
          showPermissionHint.value = false;
        } else {
          enabled.value = false;
          showPermissionHint.value = true;
          _notify(
            'Bildirim izni verilmedi',
            'Cihaz ayarlarından bildirimlere izin verin.',
          );
        }
      } else {
        await _service.disable();
        enabled.value = false;
      }
    } finally {
      busy.value = false;
    }
  }

  /// Saati kaydeder ve hatırlatıcı açıksa bildirimi yeniden kurar.
  ///
  /// Yeniden kurulum başarısız olsa bile saat tercihi kayıtlı kalır; sonraki
  /// açılışta [ReadingReminderService.ensureScheduled] tekrar dener.
  Future<void> setTime(TimeOfDay time) async {
    await _service.setTime(time.hour, time.minute);
    hour.value = _service.hour;
    minute.value = _service.minute;
    if (enabled.value) {
      // Sonuç yoksayılır: tercih kayıtlı, kurulum sessizce tekrar denenir.
      await _service.enable(
        hour: hour.value,
        minute: minute.value,
        pages: pages.value,
      );
    }
  }

  /// Günlük sayfa hedefini kaydeder ve hatırlatıcı açıksa bildirim metnini
  /// güncellemek için bildirimi yeniden kurar.
  Future<void> setPages(int value) async {
    await _service.setPages(value);
    pages.value = _service.pages;
    if (enabled.value) {
      await _service.enable(
        hour: hour.value,
        minute: minute.value,
        pages: pages.value,
      );
    }
  }
}

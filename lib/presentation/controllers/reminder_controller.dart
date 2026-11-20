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

import '../../data/services/reading_reminder_service.dart';

/// Hatırlatıcı tercihleri ve zamanlama akışının GetX denetleyicisi.
class ReadingReminderController extends GetxController {
  ReadingReminderController({
    required ReadingReminderService service,
    void Function(String title, String message)? onNotify,
  })  : _service = service,
        _notify = onNotify ?? _defaultNotify;

  final ReadingReminderService _service;
  final void Function(String title, String message) _notify;

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

  static void _defaultNotify(String title, String message) {
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }

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
  /// verilmedi) kullanıcı bilgilendirilir ve hatırlatıcı kapalı kalır.
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
        } else {
          enabled.value = false;
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

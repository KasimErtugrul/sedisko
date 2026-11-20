/// ReadingReminderController birim testleri (1.18.0 sürümüyle eklendi).
///
/// Gerçek bildirim plugin'i ÇAĞRILMAZ: denetleyici, sahte zamanlayıcıyla
/// kurulan [ReadingReminderService] üzerinden test edilir. Bilgilendirme
/// akışı [onNotify] enjeksiyonuyla kaydedilir; GetX snackbar'a gerek kalmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/constants/app_constants.dart';
import 'package:kitaplik/data/services/reading_reminder_service.dart';
import 'package:kitaplik/presentation/controllers/reminder_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zamanlama çağrısının kaydı.
class _ScheduleCall {
  const _ScheduleCall({
    required this.id,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
  });

  final int id;
  final String title;
  final String body;
  final int hour;
  final int minute;
}

/// Tek seferlik kurulum kaydı (keşke 34/35, 1.26.0): ödünç hatırlatmaları.
class _OnceCall {
  _OnceCall({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
  });

  final int id;
  final String title;
  final String body;
  final DateTime at;
}

/// Çağrıları kaydeden sahte zamanlayıcı; [result] kurulum sonucunu belirler.
class _FakeReminderScheduler implements ReminderScheduler {
  bool result = true;
  final List<_ScheduleCall> scheduleCalls = <_ScheduleCall>[];
  final List<_OnceCall> onceCalls = <_OnceCall>[];
  final List<int> cancelCalls = <int>[];

  @override
  Future<bool> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    scheduleCalls.add(_ScheduleCall(
      id: id,
      title: title,
      body: body,
      hour: hour,
      minute: minute,
    ));
    return result;
  }

  @override
  Future<bool> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    onceCalls.add(_OnceCall(id: id, title: title, body: body, at: at));
    return result;
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls.add(id);
  }
}

void main() {
  late SharedPreferences prefs;
  late _FakeReminderScheduler fake;
  late ReadingReminderService service;
  late List<({String title, String message})> notifications;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fake = _FakeReminderScheduler();
    service = ReadingReminderService(prefs: prefs, scheduler: fake);
    notifications = <({String title, String message})>[];
  });

  tearDown(() {
    Get.reset();
  });

  ReadingReminderController putController() {
    return Get.put(ReadingReminderController(
      service: service,
      onNotify: (title, message) =>
          notifications.add((title: title, message: message)),
    ));
  }

  Future<void> flushAsync() => Future<void>.delayed(Duration.zero);

  test('tercihler boşken varsayılanlarla açılır ve kurulum yapmaz', () async {
    final controller = putController();
    await flushAsync();

    expect(controller.enabled.value, isFalse);
    expect(controller.hour.value, 20);
    expect(controller.minute.value, 30);
    expect(controller.pages.value, 20);
    expect(controller.busy.value, isFalse);
    expect(fake.scheduleCalls, isEmpty);
  });

  test('açık tercih açılışta sessizce yeniden kurulur', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsKeys.reminderEnabled: true,
      SettingsKeys.reminderHour: 21,
      SettingsKeys.reminderMinute: 15,
      SettingsKeys.reminderPages: 35,
    });
    final stored = await SharedPreferences.getInstance();
    service = ReadingReminderService(prefs: stored, scheduler: fake);

    final controller = putController();
    await flushAsync();

    expect(controller.enabled.value, isTrue);
    expect(controller.hour.value, 21);
    expect(controller.minute.value, 15);
    expect(controller.pages.value, 35);
    expect(fake.scheduleCalls, hasLength(1));
    expect(fake.scheduleCalls.single.hour, 21);
    expect(fake.scheduleCalls.single.minute, 15);
    expect(
      fake.scheduleCalls.single.body,
      'Bugün 35 sayfa okuma hedefin var. İyi okumalar!',
    );
  });

  test('toggle(true) bildirimi kurar ve tercihi kalıcı yazar', () async {
    final controller = putController();

    await controller.toggle(true);

    expect(controller.enabled.value, isTrue);
    expect(controller.busy.value, isFalse);
    expect(fake.scheduleCalls, hasLength(1));
    expect(fake.scheduleCalls.single.hour, 20);
    expect(fake.scheduleCalls.single.minute, 30);
    expect(
      fake.scheduleCalls.single.body,
      'Bugün 20 sayfa okuma hedefin var. İyi okumalar!',
    );
    expect(prefs.getBool(SettingsKeys.reminderEnabled), isTrue);
    expect(notifications, isEmpty);
  });

  test('izin reddinde bilgilendirme yapar ve kapalı kalır', () async {
    final controller = putController();
    fake.result = false;

    await controller.toggle(true);

    expect(controller.enabled.value, isFalse);
    expect(prefs.getBool(SettingsKeys.reminderEnabled), isNull);
    expect(notifications, hasLength(1));
    expect(notifications.single.title, 'Bildirim izni verilmedi');
    expect(
      notifications.single.message,
      'Cihaz ayarlarından bildirimlere izin verin.',
    );
  });

  test('toggle(false) bildirimi iptal eder ve tercihi kapatır', () async {
    final controller = putController();
    await controller.toggle(true);

    await controller.toggle(false);

    expect(controller.enabled.value, isFalse);
    expect(fake.cancelCalls, [ReadingReminderService.notificationId]);
    expect(prefs.getBool(SettingsKeys.reminderEnabled), isFalse);
  });

  test('toggle sürerken ikinci çağrı yoksayılır', () async {
    final controller = putController();

    final first = controller.toggle(true);
    final second = controller.toggle(true);
    await Future.wait(<Future<void>>[first, second]);

    expect(fake.scheduleCalls, hasLength(1));
    expect(controller.busy.value, isFalse);
  });

  test('setTime saati günceller ve açıkken yeniden kurar', () async {
    final controller = putController();
    await controller.toggle(true);
    fake.scheduleCalls.clear();

    await controller.setTime(const TimeOfDay(hour: 8, minute: 5));

    expect(controller.hour.value, 8);
    expect(controller.minute.value, 5);
    expect(prefs.getInt(SettingsKeys.reminderHour), 8);
    expect(prefs.getInt(SettingsKeys.reminderMinute), 5);
    expect(fake.scheduleCalls, hasLength(1));
    expect(fake.scheduleCalls.single.hour, 8);
    expect(fake.scheduleCalls.single.minute, 5);
  });

  test('setTime kapalıyken tercih yazar ama kurulum yapmaz', () async {
    final controller = putController();

    await controller.setTime(const TimeOfDay(hour: 6, minute: 40));

    expect(controller.hour.value, 6);
    expect(controller.minute.value, 40);
    expect(prefs.getInt(SettingsKeys.reminderHour), 6);
    expect(fake.scheduleCalls, isEmpty);
  });

  test('setPages hedefi günceller ve açıkken metinle yeniden kurar',
      () async {
    final controller = putController();
    await controller.toggle(true);
    fake.scheduleCalls.clear();

    await controller.setPages(45);

    expect(controller.pages.value, 45);
    expect(prefs.getInt(SettingsKeys.reminderPages), 45);
    expect(fake.scheduleCalls, hasLength(1));
    expect(
      fake.scheduleCalls.single.body,
      'Bugün 45 sayfa okuma hedefin var. İyi okumalar!',
    );
  });
}

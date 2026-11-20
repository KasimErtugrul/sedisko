/// ReadingReminderService birim testleri (1.18.0 sürümüyle eklendi).
///
/// Gerçek bildirim plugin'i ÇAĞRILMAZ: [FakeReminderScheduler] tüm
/// zamanlama çağrılarını kaydeder ve döndürülecek sonucu test
/// kontrollüdür. Tercihler `SharedPreferences.setMockInitialValues`
/// ile sahte bellekte tutulur.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/core/constants/app_constants.dart';
import 'package:kitaplik/data/services/reading_reminder_service.dart';
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

/// Çağrıları kaydeden sahte zamanlayıcı; [result] kurulum sonucunu belirler.
class _FakeReminderScheduler implements ReminderScheduler {
  bool result = true;
  final List<_ScheduleCall> scheduleCalls = <_ScheduleCall>[];
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
  Future<void> cancel(int id) async {
    cancelCalls.add(id);
  }
}

void main() {
  late SharedPreferences prefs;
  late _FakeReminderScheduler fake;
  late ReadingReminderService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fake = _FakeReminderScheduler();
    service = ReadingReminderService(prefs: prefs, scheduler: fake);
  });

  test('tercihler boşken varsayılanlar kullanılır', () {
    expect(service.isEnabled, isFalse);
    expect(service.hour, 20);
    expect(service.minute, 30);
    expect(service.pages, 20);
    expect(fake.scheduleCalls, isEmpty);
  });

  test('bodyFor hedef sayfayı metne yerleştirir', () {
    expect(
      ReadingReminderService.bodyFor(20),
      'Bugün 20 sayfa okuma hedefin var. İyi okumalar!',
    );
    expect(
      ReadingReminderService.bodyFor(35),
      'Bugün 35 sayfa okuma hedefin var. İyi okumalar!',
    );
    expect(ReadingReminderService.title, 'Okuma hatırlatıcısı');
  });

  test('enable varsayılan değerlerle schedule çağırır ve tercihi yazar',
      () async {
    final ok = await service.enable();

    expect(ok, isTrue);
    expect(fake.scheduleCalls, hasLength(1));
    final call = fake.scheduleCalls.single;
    expect(call.id, ReadingReminderService.notificationId);
    expect(call.title, 'Okuma hatırlatıcısı');
    expect(
      call.body,
      'Bugün 20 sayfa okuma hedefin var. İyi okumalar!',
    );
    expect(call.hour, 20);
    expect(call.minute, 30);
    expect(prefs.getBool(SettingsKeys.reminderEnabled), isTrue);
  });

  test('enable açık parametreleri kalıcı yazar ve metne işler', () async {
    final ok = await service.enable(hour: 9, minute: 5, pages: 40);

    expect(ok, isTrue);
    expect(fake.scheduleCalls.single.hour, 9);
    expect(fake.scheduleCalls.single.minute, 5);
    expect(
      fake.scheduleCalls.single.body,
      'Bugün 40 sayfa okuma hedefin var. İyi okumalar!',
    );
    expect(prefs.getInt(SettingsKeys.reminderHour), 9);
    expect(prefs.getInt(SettingsKeys.reminderMinute), 5);
    expect(prefs.getInt(SettingsKeys.reminderPages), 40);
    expect(prefs.getBool(SettingsKeys.reminderEnabled), isTrue);
  });

  test('scheduler kurulum başarısız dönerse enabled yazılmaz', () async {
    fake.result = false;

    final ok = await service.enable();

    expect(ok, isFalse);
    expect(fake.scheduleCalls, hasLength(1));
    expect(prefs.getBool(SettingsKeys.reminderEnabled), isNull);
    expect(service.isEnabled, isFalse);
  });

  test('disable cancel çağırır ve tercihi kapatır', () async {
    expect(await service.enable(), isTrue);

    await service.disable();

    expect(fake.cancelCalls, [ReadingReminderService.notificationId]);
    expect(prefs.getBool(SettingsKeys.reminderEnabled), isFalse);
    expect(service.isEnabled, isFalse);
  });

  test('ensureScheduled kapalıyken schedule çağırmaz', () async {
    final ok = await service.ensureScheduled();

    expect(ok, isFalse);
    expect(fake.scheduleCalls, isEmpty);
    expect(fake.cancelCalls, isEmpty);
  });

  test('ensureScheduled açıkken kayıtlı tercihle yeniden kurar', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsKeys.reminderEnabled: true,
      SettingsKeys.reminderHour: 21,
      SettingsKeys.reminderMinute: 15,
      SettingsKeys.reminderPages: 35,
    });
    final stored = await SharedPreferences.getInstance();
    final openService =
        ReadingReminderService(prefs: stored, scheduler: fake);

    final ok = await openService.ensureScheduled();

    expect(ok, isTrue);
    expect(fake.scheduleCalls, hasLength(1));
    expect(fake.scheduleCalls.single.hour, 21);
    expect(fake.scheduleCalls.single.minute, 15);
    expect(
      fake.scheduleCalls.single.body,
      'Bugün 35 sayfa okuma hedefin var. İyi okumalar!',
    );
    expect(fake.scheduleCalls.single.id,
        ReadingReminderService.notificationId);
  });

  test('setTime 0-23 / 0-59 aralığına kırpılır', () async {
    await service.setTime(25, 90);
    expect(prefs.getInt(SettingsKeys.reminderHour), 23);
    expect(prefs.getInt(SettingsKeys.reminderMinute), 59);

    await service.setTime(-3, -1);
    expect(prefs.getInt(SettingsKeys.reminderHour), 0);
    expect(prefs.getInt(SettingsKeys.reminderMinute), 0);

    await service.setTime(7, 45);
    expect(prefs.getInt(SettingsKeys.reminderHour), 7);
    expect(prefs.getInt(SettingsKeys.reminderMinute), 45);
  });

  test('setTime schedule çağırmaz', () async {
    await service.setTime(8, 0);
    expect(fake.scheduleCalls, isEmpty);
  });

  test('setPages 1..1000 aralığına kırpılır', () async {
    await service.setPages(0);
    expect(prefs.getInt(SettingsKeys.reminderPages), 1);

    await service.setPages(1500);
    expect(prefs.getInt(SettingsKeys.reminderPages), 1000);

    await service.setPages(25);
    expect(prefs.getInt(SettingsKeys.reminderPages), 25);
  });

  test('bozuk kayıtlı değerler okuma sırasında kırpılır', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsKeys.reminderEnabled: true,
      SettingsKeys.reminderHour: 99,
      SettingsKeys.reminderMinute: -7,
      SettingsKeys.reminderPages: 5000,
    });
    final stored = await SharedPreferences.getInstance();
    final brokenService =
        ReadingReminderService(prefs: stored, scheduler: fake);

    expect(brokenService.isEnabled, isTrue);
    expect(brokenService.hour, 23);
    expect(brokenService.minute, 0);
    expect(brokenService.pages, 1000);
  });
}

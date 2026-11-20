/// Günlük okuma hatırlatıcısı servisi (1.18.0 sürümüyle eklendi).
///
/// Bu modül; kullanıcının ayarlardan açtığı günlük okuma hatırlatıcısının
/// kalıcı tercihlerini ([SettingsKeys.reminder*] anahtarlarıyla
/// SharedPreferences'a) ve bildirim zamanlamasını yönetir. Her gün seçilen
/// saatte tek bir yerel bildirim kurulur: 'Okuma hatırlatıcısı — Bugün
/// N sayfa okuma hedefin var. İyi okumalar!'.
///
/// Katman ayrımı: [ReadingReminderService] saf tercihi (SharedPreferences
/// + soyut [ReminderScheduler]) yönetir; [FlutterReminderScheduler] ise
/// flutter_local_notifications + flutter_timezone + timezone paketlerini
/// sarmalar. Böylece widget/denetleyici testlerinde gerçek plugin
/// çağrılmadan sahte zamanlayıcı enjekte edilebilir.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/app_constants.dart';

/// Bildirim zamanlayıcı soyutlaması: gerçek plugin sarmalayıcısı testlerde
/// sahteyle değiştirilebilir.
abstract class ReminderScheduler {
  /// Günlük tekrarlı bildirim kurar. İzin/timezone kurulamadıysa false.
  Future<bool> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  });

  /// Verilen kimlikteki planlı bildirimi iptal eder.
  Future<void> cancel(int id);
}

/// [ReminderScheduler]ın gerçek uygulaması.
///
/// Tembel tek seferlik kurulum: plugin `initialize` + yerel saat dilimi
/// ayarı yalnızca ilk [scheduleDaily] çağrısında yapılır; sonraki
/// çağrılar hazır durumu yeniden kullanır. Tüm plugin çağrıları
/// try-catch ile sarılır: hata durumunda asla istisna fırlatılmaz,
/// yalnızca false döner.
class FlutterReminderScheduler implements ReminderScheduler {
  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;

  /// Plugin ve yerel saat dilimi verisini hazırlar; başarısızsa false.
  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      final plugin = _plugin ??= FlutterLocalNotificationsPlugin();
      final ok = await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      if (ok == false) return false;
      // Saat dilimi: TZDateTime hesapları için yerel konum şart. Veri
      // yüklenemezse (örn. hatalı IANA adı) kurulum başarısız sayılır.
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      _initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      // Web/masaüstünde yerel bildirim anlamlı değildir; kurulum yapılmaz
      // ama tercih akışı bozulmasın diye başarı döner.
      return true;
    }
    try {
      if (!await _ensureInitialized()) return false;

      // İzinler: Android 13+ POST_NOTIFICATIONS, iOS uyarı/ses/rozet.
      if (Platform.isAndroid) {
        final android = _plugin?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (android == null) return false;
        final granted = await android.requestNotificationsPermission();
        if (granted == false) return false;
      } else if (Platform.isIOS) {
        final ios = _plugin?.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (ios == null) return false;
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        if (granted == false) return false;
      }

      // Sıradaki hour:minute yerel zamanı: bugün geçtiyse yarın.
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!scheduledDate.isAfter(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _plugin!.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin?.cancel(id: id);
    } catch (_) {
      // İptal edilemese de uygulama akışı bozulmaz; sessizce yok sayılır.
    }
  }
}

/// Android bildirim kanalı tanımları.
const String _channelId = 'okuma_hatirlatici';
const String _channelName = 'Okuma hatırlatıcısı';
const String _channelDescription = 'Günlük okuma hedefi hatırlatması';

/// Okuma hatırlatıcısının kalıcı tercihleri ve zamanlama akışı.
///
/// Servis yalnızca tercihleri yazar ve zamanlayıcıyı çağırır; metin üretimi
/// saf (statik, [bodyFor]) tutulur. Kullanıcı tercihini değiştirdiğinde
/// denetleyici gerektiğinde [enable] ile yeniden kurar.
class ReadingReminderService {
  ReadingReminderService({
    required SharedPreferences prefs,
    required ReminderScheduler scheduler,
  })  : _prefs = prefs,
        _scheduler = scheduler;

  final SharedPreferences _prefs;
  final ReminderScheduler _scheduler;

  /// Tek bildirim kimliği: her gün aynı kimlikle kurulur ve iptal edilir.
  static const int notificationId = 18202611;

  static const int _defaultHour = 20;
  static const int _defaultMinute = 30;
  static const int _defaultPages = 20;

  static const int _maxHour = 23;
  static const int _maxMinute = 59;
  static const int _minPages = 1;
  static const int _maxPages = 1000;

  /// Hatırlatıcı açık mı? Varsayılan kapalı: bildirim sessiz bir uygulamada
  /// sürpriz olur.
  bool get isEnabled => _prefs.getBool(SettingsKeys.reminderEnabled) ?? false;

  /// Hatırlatma saati (0-23). Kayıtlı değer bozuksa aralığa kırpılır.
  int get hour =>
      _clamp(_prefs.getInt(SettingsKeys.reminderHour) ?? _defaultHour, 0, _maxHour);

  /// Hatırlatma dakikası (0-59). Kayıtlı değer bozuksa aralığa kırpılır.
  int get minute =>
      _clamp(_prefs.getInt(SettingsKeys.reminderMinute) ?? _defaultMinute, 0,
          _maxMinute);

  /// Günlük sayfa hedefi (1-1000). Kayıtlı değer bozuksa aralığa kırpılır.
  int get pages => _clamp(
      _prefs.getInt(SettingsKeys.reminderPages) ?? _defaultPages,
      _minPages,
      _maxPages);

  /// Hatırlatıcıyı açar: saat/dakika/sayfa tercihlerini kalıcı yazar,
  /// günlük bildirimi kurar. Zamanlayıcı kurulumu başarısızsa (örn. izin
  /// verilmedi) `enabled=true` YAZILMAZ ve false döner.
  Future<bool> enable({int? hour, int? minute, int? pages}) async {
    final h = hour != null ? _clamp(hour, 0, _maxHour) : this.hour;
    final m = minute != null ? _clamp(minute, 0, _maxMinute) : this.minute;
    final p = pages != null ? _clamp(pages, _minPages, _maxPages) : this.pages;
    await _prefs.setInt(SettingsKeys.reminderHour, h);
    await _prefs.setInt(SettingsKeys.reminderMinute, m);
    await _prefs.setInt(SettingsKeys.reminderPages, p);
    final ok = await _scheduler.scheduleDaily(
      id: notificationId,
      title: title,
      body: bodyFor(p),
      hour: h,
      minute: m,
    );
    if (!ok) return false;
    await _prefs.setBool(SettingsKeys.reminderEnabled, true);
    return true;
  }

  /// Hatırlatıcıyı kapatır: planlı bildirimi iptal eder ve tercihi kapatır.
  Future<void> disable() async {
    await _scheduler.cancel(notificationId);
    await _prefs.setBool(SettingsKeys.reminderEnabled, false);
  }

  /// Saati yalnızca tercihe yazar (0-23 / 0-59 kırpılır). Bildirimi
  /// yeniden kurmaz: açıkken denetleyici [enable] ile yeniden kurar.
  Future<void> setTime(int hour, int minute) async {
    await _prefs.setInt(
        SettingsKeys.reminderHour, _clamp(hour, 0, _maxHour));
    await _prefs.setInt(
        SettingsKeys.reminderMinute, _clamp(minute, 0, _maxMinute));
  }

  /// Sayfa hedefini yalnızca tercihe yazar (1..1000 kırpılır). Bildirimi
  /// yeniden kurmaz: açıkken denetleyici [enable] ile yeniden kurar.
  Future<void> setPages(int pages) async {
    await _prefs.setInt(
        SettingsKeys.reminderPages, _clamp(pages, _minPages, _maxPages));
  }

  /// Açılışta güvenli yeniden kurulum: hatırlatıcı açıksa bildirim yeniden
  /// kurulur (uygulama güncellenip cihaz yeniden başladığında alarm
  /// sıfırlanmış olabilir). Kapalıysa false döner ve hiçbir işlem yapmaz.
  Future<bool> ensureScheduled() async {
    if (!isEnabled) return false;
    return _scheduler.scheduleDaily(
      id: notificationId,
      title: title,
      body: bodyFor(pages),
      hour: hour,
      minute: minute,
    );
  }

  /// Bildirim metni; sayfa hedefi metnin içine yerleşir.
  static String bodyFor(int pages) =>
      'Bugün $pages sayfa okuma hedefin var. İyi okumalar!';

  /// Bildirim başlığı.
  static String get title => 'Okuma hatırlatıcısı';

  static int _clamp(int value, int lowerBound, int upperBound) {
    if (value < lowerBound) return lowerBound;
    if (value > upperBound) return upperBound;
    return value;
  }
}

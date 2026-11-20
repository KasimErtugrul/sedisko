/// ReadingReminderSection widget testleri (1.18.0 sürümüyle eklendi).
///
/// Gerçek bildirim plugin'i ÇAĞRILMAZ: bölüm, sahte zamanlayıcıyla kurulan
/// [ReadingReminderService] üzerinden kayıtlı [ReadingReminderController]
/// ile pump edilir. Ayrıca bölümün denetleyici kayıtsızken ve gerçek
/// Ayarlar sayfası içinde hatasız boş kurulduğu denetlenir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/constants/app_constants.dart';
import 'package:kitaplik/data/services/reading_reminder_service.dart';
import 'package:kitaplik/presentation/controllers/reminder_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/settings_page.dart';
import 'package:kitaplik/presentation/widgets/reminder/reading_reminder_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Çağrıları kaydeden sahte zamanlayıcı; plugin'e dokunmaz.
class _FakeReminderScheduler implements ReminderScheduler {
  bool result = true;
  int scheduleCount = 0;
  final List<int> cancelCalls = <int>[];

  @override
  Future<bool> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    scheduleCount++;
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

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fake = _FakeReminderScheduler();
  });

  tearDown(() {
    Get.reset();
  });

  /// Denetleyici kayıtlıyken bölümü pump eder.
  Future<ReadingReminderController> pumpSection(WidgetTester tester) async {
    final service = ReadingReminderService(prefs: prefs, scheduler: fake);
    final controller = Get.put(ReadingReminderController(
      service: service,
      onNotify: (title, message) {},
    ));
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [ReadingReminderSection()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('kapalıyken yalnızca başlık ve anahtar görünür', (tester) async {
    await pumpSection(tester);

    expect(find.text('Okuma hatırlatıcısı'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text('Günlük okuma hatırlatıcısı'), findsOneWidget);
    expect(find.text('Seçtiğin saatte günlük sayfa hedefini bildirir'),
        findsOneWidget);
    // Kapalıyken saat ve hedef satırları çizilmez.
    expect(find.text('Hatırlatma saati'), findsNothing);
    expect(find.text('Günlük sayfa hedefi'), findsNothing);
  });

  testWidgets('anahtar açıkken bildirim kurulur ve saat satırı görünür',
      (tester) async {
    await pumpSection(tester);

    await tester.tap(find.text('Günlük okuma hatırlatıcısı'));
    await tester.pumpAndSettle();

    // Saat satırı iki hane padlenmiş değeri gösterir.
    expect(find.text('Hatırlatma saati'), findsOneWidget);
    expect(find.text('20:30'), findsOneWidget);
    expect(find.text('Günlük sayfa hedefi'), findsOneWidget);
    expect(find.text('20 sayfa'), findsOneWidget);
    expect(fake.scheduleCount, 1);
    expect(prefs.getBool(SettingsKeys.reminderEnabled), isTrue);
  });

  testWidgets('sayfa hedefi diyaloğu hedefi kalıcı günceller',
      (tester) async {
    await pumpSection(tester);
    await tester.tap(find.text('Günlük okuma hatırlatıcısı'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Günlük sayfa hedefi'));
    await tester.pumpAndSettle();

    // Diyalog mevcut değerle açılır.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '20',
    );

    await tester.enterText(find.byType(TextField), '45');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('45 sayfa'), findsOneWidget);
    expect(prefs.getInt(SettingsKeys.reminderPages), 45);
    expect(fake.scheduleCount, 2); // açılış + hedef değişimi
  });

  testWidgets('diyalogda Vazgeç hiçbir şey değiştirmez', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.text('Günlük okuma hatırlatıcısı'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Günlük sayfa hedefi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '999');
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('20 sayfa'), findsOneWidget);
    expect(prefs.getInt(SettingsKeys.reminderPages), 20);
    expect(fake.scheduleCount, 1);
  });

  testWidgets('denetleyici kayıtsızken bölüm boş kurulur', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [ReadingReminderSection()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Okuma hatırlatıcısı'), findsNothing);
    expect(find.text('Günlük okuma hatırlatıcısı'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('gerçek Ayarlar sayfası denetleyicisiz bölümle hatasız kurulur',
      (tester) async {
    // Yalnız SettingsController kayıtlı: hatırlatıcı bölümü kendini
    // gizler ve sayfa kurulum hatası vermez (entegrasyon güvenliği).
    final settings = Get.put(SettingsController(prefs: prefs));
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Görünüm'), findsOneWidget);
    expect(find.text('Kitaplığım ${AppInfo.version}'), findsOneWidget);
    expect(find.text('Günlük okuma hatırlatıcısı'), findsNothing);
    expect(settings.showCovers.value, isTrue);
  });
}

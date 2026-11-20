import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/services/reading_reminder_service.dart';
import 'package:kitaplik/presentation/controllers/reminder_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/pages/settings_page.dart';
import 'package:kitaplik/presentation/widgets/reminder/reading_reminder_section.dart';
import 'package:kitaplik/presentation/utils/haber_seridi.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keşke 39 + 42 (1.26.0):
///
/// - Keşke 39: bildirim izni verilmezse kullanıcı yalnız bırakılmaz —
///   'Ayarlara git' düğmeli satır çıkar ve düğme cihaz ayarlarını açan
///   enjekte edilebilir yolu çağırır ("O ayarı bulmak benim için bir
///   macera; düğme olsaydı direkt giderdim").
/// - Keşke 42: 'Barkod tarama' anahtarı kapatılınca sonuç EKRANDA KALAN
///   şeritle söylenir ("Kapatınca 'Barkod düğmeleri artık hiçbir yerde
///   görünmeyecek' deseydi, şaşırmazdım").
void main() {
  late SharedPreferences prefs;
  late List<String> notifications;
  var settingsOpened = 0;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    notifications = [];
    settingsOpened = 0;
  });

  tearDown(() {
    Get.reset();
    kaldirHaberSeridi();
  });

  ReadingReminderController buildReminderController({
    bool enableFails = false,
  }) {
    final service = _FailingService(enableFails);
    return Get.put(ReadingReminderController(
      service: service,
      onOpenDeviceSettings: () async => settingsOpened++,
      onNotify: (title, message) => notifications.add('$title|$message'),
    ));
  }

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: ListView(children: const [ReadingReminderSection()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'keşke 39: izin verilmez anahtar, Ayarlara git düğmeli satır çıkarır',
      (tester) async {
    final controller = buildReminderController(enableFails: true);
    await pumpSection(tester);

    expect(find.byKey(const Key('reminder-permission-row')), findsNothing);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // Anahtar kapalı kalır; izin satırı kurulu olur.
    expect(controller.enabled.value, isFalse);
    expect(find.byKey(const Key('reminder-permission-row')), findsOneWidget);
    expect(find.text('Bildirim izni verilmedi'), findsOneWidget);
    expect(find.text('Ayarlara git'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reminder-open-settings')));
    await tester.pumpAndSettle();

    expect(settingsOpened, 1);
  });

  testWidgets(
      'keşke 39: hatırlatıcı açılınca izin satırı kaybolur', (tester) async {
    final controller = buildReminderController();
    await pumpSection(tester);

    // Önce başarısız kür: satır kurulsun.
    controller.showPermissionHint.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-permission-row')), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(controller.enabled.value, isTrue);
    expect(find.byKey(const Key('reminder-permission-row')), findsNothing);
  });

  testWidgets('keşke 42: barkod anahtarı kapatılınca ekranda kalan şerit',
      (tester) async {
    Get.put(SettingsController(prefs: prefs), permanent: true);
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Barkod tarama'));
    await tester.pumpAndSettle();

    expect(Get.find<SettingsController>().showScanActions.value, isFalse);
    expect(find.text('Barkod tarama kapandı'), findsOneWidget);
    expect(
      find.textContaining('hiçbir yerde görünmeyecek'),
      findsOneWidget,
    );
    // Şerit ekranda KALIR: zamanla kaybolmaz (keşke 44'ün sözü).
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Barkod tarama kapandı'), findsOneWidget);

    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();
    expect(find.text('Barkod tarama kapandı'), findsNothing);
  });

  testWidgets('keşke 42: barkod anahtarı açılınca geri geldi şeridi',
      (tester) async {
    final controller = Get.put(SettingsController(prefs: prefs), permanent: true);
    controller.setShowScanActions(false);
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Barkod tarama'));
    await tester.pumpAndSettle();

    expect(controller.showScanActions.value, isTrue);
    expect(find.text('Barkod tarama açıldı'), findsOneWidget);
    expect(find.text('"Barkod tara" düğmeleri geri geldi.'), findsOneWidget);
  });
}

/// İzin akışının sahteyle kontrol edildiği servis: [enableFails] doğruysa
/// kurulum başarısız döner (izin yok senaryosu).
class _FailingService implements ReadingReminderService {
  // Yalnız enable() davranışını kandırmak için: scheduler'a dokunmaz.
  _FailingService(this.failEnable);

  final bool failEnable;

  @override
  Future<bool> enable({int? hour, int? minute, int? pages}) async =>
      !failEnable;

  @override
  Future<void> disable() async {}

  @override
  Future<bool> ensureScheduled() async => false;

  @override
  int get hour => 20;

  @override
  bool get isEnabled => false;

  @override
  int get minute => 30;

  @override
  int get pages => 20;

  @override
  Future<void> setPages(int pages) async {}

  @override
  Future<void> setTime(int hour, int minute) async {}

}

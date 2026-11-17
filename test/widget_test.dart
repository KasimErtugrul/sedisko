import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/main.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Orijinal repodaki widget_test.dart tamamen yorumsuzdu ve var olmayan
  // MyApp sınıfına referans veriyordu; aşağıdaki testler gerçek ekranları
  // doğrular.

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // main() üretimde kaydeder; testte KitaplikApp'ten önce kaydedilir.
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    await tester.pumpWidget(KitaplikApp(prefs: prefs));
    await tester.pumpAndSettle();
  }

  testWidgets('ana sayfa boş kitaplık durumuyla açılır', (tester) async {
    await pumpApp(tester);

    expect(find.text('Kitaplığım'), findsOneWidget); // AppBar başlığı
    expect(find.text('Kitap ekle'), findsOneWidget); // FAB
    expect(
      find.text('Kitaplığın boş.\nİlk kitabını barkod tarayarak ekle.'),
      findsOneWidget,
    );
  });

  testWidgets('arama alanında yazınca temizle butonu çıkar', (tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.byType(TextField).first,
      'istanbul',
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Aramayı temizle'), findsOneWidget);

    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Aramayı temizle'), findsNothing);
  });

  testWidgets('FAB ekle menüsünü açar ve manuel form ekranına gider',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Manuel ekle'), findsOneWidget);
    expect(find.text('Barkod tara'), findsOneWidget);

    await tester.tap(find.text('Manuel ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Yeni kitap'), findsOneWidget); // form AppBar başlığı
  });

  testWidgets('formda zorunlu alanlar boş kaydedilemez', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuel ekle'));
    await tester.pumpAndSettle();

    // ListView tembel yapıdadır; Kaydet butonu ağaçta yoksa önce kaydır.
    final scrollable = find.byType(Scrollable).first;
    final kaydetFinder = find.text('Kaydet');
    await tester.scrollUntilVisible(kaydetFinder, 200, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.tap(kaydetFinder);
    await tester.pumpAndSettle();

    // Doğrulama hataları; üst alanlar görünümden çıktıysa geri kaydır.
    final titleError = find.text('Kitap adı gerekli');
    await tester.scrollUntilVisible(titleError, -200, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(titleError, findsOneWidget);

    final shelfError = find.text('Raf bilgisi gerekli');
    await tester.scrollUntilVisible(shelfError, 200, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(shelfError, findsOneWidget);
  });
}

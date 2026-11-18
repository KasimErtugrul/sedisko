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
    // Form bitirme hedefi alanıyla uzadı; tek ekrana sığacak kadar yüksek
    // yüzey kullanılır. Böylece üstteki alanlar ListView tembel kurulumundan
    // düşüp Form.validate() dışında kalmaz ve hata metinleri doğrudan
    // görünür olur.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuel ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Yeni kitap'), findsOneWidget);
    expect(find.text('Bitirme hedefi (isteğe bağlı)'), findsOneWidget);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    // Zorunlu alan hataları görünür; kayıt gerçekleşmez (hâlâ formdayız).
    expect(find.text('Kitap adı gerekli'), findsOneWidget);
    expect(find.text('Raf bilgisi gerekli'), findsOneWidget);
    expect(find.text('Yeni kitap'), findsOneWidget);
  });
}

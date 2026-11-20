import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/presentation/utils/haber_seridi.dart';

/// Keşke 44 (1.25.0) — haber şeridi: önemli haberler üç saniyelik
/// balonlarla değil, ekranda kalan bir şeritle söylenir.
///
/// Hasan'ın notu: "'Taşındı', 'Kaydedildi', 'Yazar güncellendi'... hepsi
/// alttan kayıp gidiyor. Okumaya vaktim olmuyor; balon gittiğinde ne
/// olduğunu bilmiyorum."
///
/// Bu testler şeridin dört kuralını savunur:
/// 1. şerit kurulur ve 'Anladım' ile kapatılır;
/// 2. şerit zamanla kaybolmaz (snackbar'ın aksine);
/// 3. şerit snackbar'ı TIKAMAZ — 'Kitap silindi — Geri Al' gibi alttan
///    çıkan haberler bozulmaz;
/// 4. yeni şerit eskinin yerine geçer, şerit yığılmaz.
void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: const Scaffold(
          body: Center(
            child: Text('sayfa gövdesi',
                style: TextStyle(color: Colors.transparent)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('şerit kurulur ve Anladım ile kapatılır', (tester) async {
    await pumpHost(tester);

    haberSeridiGoster(baslik: 'Taşındı', mesaj: '5 kitap "Raf 2"ye gitti.');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('haber-seridi')), findsOneWidget);
    expect(find.text('Taşındı'), findsOneWidget);
    expect(find.text('5 kitap "Raf 2"ye gitti.'), findsOneWidget);
    expect(find.text('Anladım'), findsOneWidget);

    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('haber-seridi')), findsNothing);
    expect(find.text('Taşındı'), findsNothing);
  });

  testWidgets('şerit zamanla kaybolmaz; balon gibi giderken okumaya '
      'vakit bırakır', (tester) async {
    await pumpHost(tester);

    haberSeridiGoster(baslik: 'Kaydedildi', mesaj: 'Simyacı');
    // Snackbar'ın ömrünü (4 sn) ve katını geçen sürelerde şerit durur.
    for (final seconds in const [2, 4, 8]) {
      await tester.pump(Duration(seconds: seconds));
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('haber-seridi')), findsOneWidget);
    expect(find.text('Kaydedildi'), findsOneWidget);
    expect(find.text('Simyacı'), findsOneWidget);
  });

  testWidgets('şerit snackbar kuyruğunu tıkamaz; ikisi ayrı yaşar',
      (tester) async {
    await pumpHost(tester);

    haberSeridiGoster(baslik: 'Taşındı', mesaj: 'Simyacı → Raf 2.');
    await tester.pumpAndSettle();

    // Şerit açıkken alttan normal bir haber çıkar (örn. geri al teklifi).
    Get.snackbar('Kitap silindi', 'Altı saniye içinde Geri Alabilirsin.');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('haber-seridi')), findsOneWidget);
    expect(find.text('Taşındı'), findsOneWidget);
    expect(find.text('Kitap silindi'), findsOneWidget);

    // Balon kendi süresiyle gider; şerit yine yerinde durur.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Kitap silindi'), findsNothing);
    expect(find.byKey(const ValueKey('haber-seridi')), findsOneWidget);
    expect(find.text('Taşındı'), findsOneWidget);
  });

  testWidgets('yeni şerit eskisinin yerine geçer; şerit yığılmaz',
      (tester) async {
    await pumpHost(tester);

    haberSeridiGoster(baslik: 'Kaydedildi', mesaj: 'Simyacı');
    await tester.pumpAndSettle();
    haberSeridiGoster(
        baslik: 'Yazar güncellendi', mesaj: '3 kitap yazıldı.');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('haber-seridi')), findsOneWidget);
    expect(find.text('Yazar güncellendi'), findsOneWidget);
    expect(find.text('Kaydedildi'), findsNothing);
    expect(find.text('Simyacı'), findsNothing);
  });

  testWidgets('şerit rota geçişinde durur ve sıkışmaz (1.23 form akışı '
      'regresyonu: formdan kaydet, ana sayfaya dön)', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpHost(tester);

    // Rota üstüne çık, şeridi göster, hemen geri dön — kaydet akışının
    // birebir taklidi (MaterialBanner'ın Hero uçuşu burada taşardı).
    Get.to(const Scaffold(body: Center(child: Text('form sayfası'))));
    await tester.pumpAndSettle();
    haberSeridiGoster(baslik: 'Kaydedildi', mesaj: 'Repro Kitabı');
    Get.back();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('haber-seridi')), findsOneWidget);
    expect(find.text('Kaydedildi'), findsOneWidget);
    expect(find.text('Repro Kitabı'), findsOneWidget);
  });
}

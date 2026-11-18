import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/widgets/cover_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CoverImage kaynak seçimi: yerel fotoğraf (path) önceliklidir, yoksa
/// ağ kapağı (url), ikisi de yoksa yer tutucu.
///
/// Not: testler gerçek dosya G/Ç'si yapmaz — testWidgets sahte-zaman
/// (FakeAsync) bölgesinde çalışır ve gerçek dosya okuma/yazma orada
/// tamamlanmaz. Sağlayıcı TÜRÜ widget kurulum anında senkron belirlenir;
/// yolda dosyanın gerçekten var olması gerekmez.

/// cacheWidth verilmişse sağlayıcı ResizeImage sarmalısında gelir;
/// iç sağlayıcıyı döndürür.
ImageProvider innerProvider(Image image) {
  final provider = image.image;
  return provider is ResizeImage ? provider.imageProvider : provider;
}

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
    await tester.pump();
  }

  testWidgets('path verilirse yerel dosya gösterilir', (tester) async {
    await pump(
      tester,
      const CoverImage(
        path: '/documents/covers/cover_1.jpg',
        url: 'https://example.com/c.jpg',
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(innerProvider(image), isA<FileImage>());
  });

  testWidgets('path yoksa ağ kapağı kullanılır', (tester) async {
    await pump(
      tester,
      const CoverImage(url: 'https://example.com/c.jpg'),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(innerProvider(image), isA<NetworkImage>());
  });

  testWidgets('path boş string ise de ağ kapağı kullanılır', (tester) async {
    await pump(
      tester,
      const CoverImage(path: '', url: 'https://example.com/c.jpg'),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(innerProvider(image), isA<NetworkImage>());
  });

  testWidgets('dosya ve url yoksa yer tutucu gösterilir', (tester) async {
    await pump(tester, const CoverImage());

    expect(find.byIcon(Icons.menu_book), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('kapak tercihi kapalıyken yerel fotoğraf yine gösterilir',
      (tester) async {
    Get.testMode = true;
    addTearDown(Get.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = Get.put(SettingsController(prefs: prefs));
    settings.setShowCovers(false);

    await pump(
      tester,
      const CoverImage(
        path: '/documents/covers/cover_2.jpg',
        url: 'https://example.com/c.jpg',
      ),
    );

    // Yerel fotoğraf internet kaynağı değildir; tercih kapalı olsa da gösterilir.
    final image = tester.widget<Image>(find.byType(Image));
    expect(innerProvider(image), isA<FileImage>());

    // Aynı tercihte ağ kapağı yine yer tutucuya düşer.
    await pump(tester, const CoverImage(url: 'https://example.com/c.jpg'));
    expect(find.byIcon(Icons.menu_book), findsOneWidget);
  });
}

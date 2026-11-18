import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/routes/app_pages.dart';
import 'package:kitaplik/presentation/routes/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'responsive_shell_test.dart' show FakeBookRepository;

/// Taşma (overflow) savunma testleri.
///
/// Kullanıcı kuralı: "overflow olma durumlarına karşı gerekli tedbirler
/// alınsın". En riskli koşullar tek tek kurularak ekranda kurulan BÜTÜN
/// widget'lar yerleştirilirken istisna düşüp düşmediği denetlenir:
/// - en küçük telefon (360) ve en geniş tablet (1280),
/// - en küçük (0.85) ve en büyük (1.3) yazı boyutu kademeleri,
/// - dört sekmenin tümü (ana sayfa, raflar, yazarlar, ayarlar).
///
/// Uzun başlık/yazar/yayınevi/hedef metinleri bilerek beslenir; sarı-siyah
/// taşma şeridi kurulum sırasında `FlutterError` olarak yükselir.
void main() {
  late FakeBookRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      BookModel(
        id: 'b1',
        title: 'Çok Çok Uzun Bir Kitap Adı Olarak Simyacının Sonuncu Yolculuğu '
            'Ve Bitmeyen Hikâyesinin Tüm Ayrıntıları',
        shelf: 'Uzun Raf Adına Sahip Raflardan Biri Burada',
        authors: ['Birinci Uzun Adlı Yazar', 'İkinci Uzun Adlı Yazar'],
        publisher: 'Çok Uzun Adlı Bir Yayınevi Yayınları Basım Evi',
        publishDate: '1999',
        pageCount: 480,
        currentPage: 120,
        addedAt: DateTime(2026, 1, 1),
        startedAt: DateTime(2026, 1, 2),
        status: ReadingStatus.reading,
        isFavorite: true,
        notes: 'Burada uzun bir not metni bulunuyor; not aldıkların '
            'şeridinde bu kitap görünsün diye yazıldı.',
        targetFinishDate: DateTime.now().add(const Duration(days: 45)),
      ),
      BookModel(
        id: 'b2',
        title: 'Kısa',
        shelf: '',
        addedAt: DateTime(2026, 1, 2),
        status: ReadingStatus.finished,
        finishedAt: DateTime(2026, 1, 10),
      ),
      BookModel(
        id: 'b3',
        title: 'Gecikmiş Hedefli Kitap Adı Burada Biraz Uzun Tutuluyor',
        shelf: 'Roman',
        authors: ['Tek Yazar'],
        pageCount: 200,
        addedAt: DateTime(2026, 1, 3),
        targetFinishDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ]);
    final controller = Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await controller.loadBooks();
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pumpAt(
    WidgetTester tester, {
    required Size size,
    required double scale,
  }) async {
    Get.find<SettingsController>().setTextScale(scale);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> visitTabs(WidgetTester tester) async {
    // Ana sayfa zaten açık. Diğer üç sekme ziyaret edilir; her sekmede
    // kurulum sırasında istisna varsa test patlar.
    for (final label in ['Raflar', 'Yazarlar', 'Ayarlar', 'Ana Sayfa']) {
      await tester.tap(find.text(label).hitTestable());
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Geniş ekran/kademe koşulunda $label sekmesinde taşma var',
      );
    }
  }

  for (final entry in {
    'telefon dikey': const Size(360, 3000),
    'tablet dikey': const Size(768, 3000),
    'tablet yatay': const Size(1280, 2000),
  }.entries) {
    for (final scaleEntry in const [0.85, 1.3].indexed) {
      final scale = scaleEntry.$2;
      testWidgets('${entry.key}, yazı boyutu $scale: taşma yok',
          (tester) async {
        await pumpAt(tester, size: entry.value, scale: scale);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Ana sayfa kurulumunda taşma var',
        );
        await visitTabs(tester);
      });
    }
  }
}

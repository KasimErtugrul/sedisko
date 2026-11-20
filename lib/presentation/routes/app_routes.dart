class Routes {
  const Routes._();

  /// Açılış karşılama ekranı ('sedişko', 1.25.0). Bekletme süresi
  /// dolunca ana sayfaya geçilir; yığından silinir (Get.offNamed).
  static const String splash = '/splash';

  /// Alt navigasyonlu kabuk: 'Raflar' + 'Ayarlar' sekmeleri.
  static const String home = '/';
  static const String shelf = '/shelf';
  static const String scanner = '/scanner';
  static const String form = '/form';
  static const String detail = '/detail';

  /// Raf düzeni asistanı: tanım düzenleme, kurulum, önizleme, plan.
  static const String shelfEditor = '/shelf-editor';
  static const String organizeSetup = '/organize-setup';
  static const String organizePreview = '/organize-preview';
  static const String organizePlan = '/organize-plan';

  /// Open Library başlık/yazar araması (1.18.0).
  static const String search = '/search';

  /// 'Uygulama nasıl kullanılır?' yardım sayfası (keşke 2, 1.26.0).
  static const String help = '/help';

  /// Satın alınacaklar listesi (1.18.0).
  static const String wishlist = '/wishlist';

  /// Ödünç verilenler (tüm geçmiş) ve ödünç alınanlar sayfaları (1.18.0).
  static const String loans = '/loans';
  static const String borrowed = '/borrowed';
}

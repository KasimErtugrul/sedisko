class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = 'https://openlibrary.org';
  static const String booksEndpoint = '/api/books';
  static const Duration timeout = Duration(seconds: 10);
}

/// Ayarlar sayfasının alt bilgisinde gösterilen sürüm; pubspec.yaml ile
/// eşit tutulur.
class AppInfo {
  const AppInfo._();

  static const String version = '1.18.0';
}

class StorageKeys {
  const StorageKeys._();

  static const String books = 'books_v1';

  /// Raf tanımları (ad + kapasite + yer + sıra). Kitapların raf ataması
  /// hâlâ `books_v1` içindeki `shelf` alanında durur; burada yalnızca
  /// fiziksel rafın tanımı tutulur.
  static const String shelves = 'shelves_v1';

  /// Sürüyor olan taşıma planı (turlar + tamamlananlar). Plan bitince
  /// anahtar silinir.
  static const String organizePlan = 'organize_plan_v1';

  /// Ödünç VERİLEN kitap kayıtları (kitap kimliği + kişi + tarih).
  /// Kitabın kendisi hâlâ `books_v1` içinde yaşar; burada yalnızca
  /// ödünç ilişkisi tutulur.
  static const String loans = 'loans_v1';

  /// Başkasından ÖDÜNÇ ALINAN kitaplar (kitaplıkta olmayan, sahibi
  /// belli kitapların takip listesi).
  static const String borrowed = 'borrowed_v1';

  /// Satın alınacaklar listesi (Open Library aramasından ya da elle
  /// eklenen, kitaplığa henüz girmemiş kitaplar).
  static const String wishlist = 'wishlist_v1';
}

/// Ayarlar sayfasının kalıcı tercih anahtarları.
class SettingsKeys {
  const SettingsKeys._();

  /// ThemeMode.index (0 = sistem, 1 = aydınlık, 2 = karanlık).
  static const String themeMode = 'settings_theme_mode';

  static const String showCovers = 'settings_show_covers';
  static const String haptics = 'settings_haptics';
  static const String scanActions = 'settings_scan_actions';

  /// Seçili renk paleti kimliği ('varsayilan', 'orman', …, 'custom').
  static const String paletteId = 'settings_palette_id';

  /// Kullanıcının kendi seçtiği tohum rengi (ARGB, işaretli int).
  static const String customSeed = 'settings_custom_seed';

  /// Yazı boyutu çarpanı (0.85 / 1.0 / 1.15 / 1.3).
  static const String textScale = 'settings_text_scale';

  /// Favori rafın `shelves_v1` kimliği; raf silinirse geçersiz sayılır.
  /// Raf düzeni asistanı favori yazarların kitaplarını bu rafa yerleştirir.
  static const String favoriteShelfId = 'settings_favorite_shelf_id';

  /// Favori yazarlar (kullanıcının sıraladığı liste).
  static const String favoriteAuthors = 'settings_favorite_authors';

  /// Kapasite kitap sayısı yerine yer (birim) cinsinden hesaplansın mı?
  /// Kitabın yeri sayfa sayısından tahmin edilir (≈350 sayfa = 1 birim).
  /// Varsayılan açıktır.
  static const String thicknessAware = 'settings_thickness_aware';

  /// Günlük okuma hatırlatıcısı açık mı? Varsayılan kapalı gelir:
  /// bildirim sessiz bir uygulamada sürpriz olur.
  static const String reminderEnabled = 'settings_reminder_enabled';

  /// Hatırlatma saati (0-23) ve dakikası (0-59). Saat yoksa 20:30
  /// varsayılır; kullanıcı saati seçtiğinde yazılır.
  static const String reminderHour = 'settings_reminder_hour';
  static const String reminderMinute = 'settings_reminder_minute';

  /// Günlük sayfa hedefi; hatırlatma metninde gösterilir. Varsayılan 20.
  static const String reminderPages = 'settings_reminder_pages';
}

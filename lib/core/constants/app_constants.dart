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

  static const String version = '1.4.0';
}

class StorageKeys {
  const StorageKeys._();

  static const String books = 'books_v1';
}

/// Ayarlar sayfasının kalıcı tercih anahtarları.
class SettingsKeys {
  const SettingsKeys._();

  /// ThemeMode.index (0 = sistem, 1 = aydınlık, 2 = karanlık).
  static const String themeMode = 'settings_theme_mode';

  static const String showCovers = 'settings_show_covers';
  static const String haptics = 'settings_haptics';
  static const String scanActions = 'settings_scan_actions';
}

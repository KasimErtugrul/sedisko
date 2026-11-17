/// Uygulama genelinde kullanılan istisna sınıfları.
///
/// Her istisna, kullanıcıya doğrudan gösterilebilecek Türkçe bir
/// [message] taşır; teknik detaylar [cause] içinde ayrı tutulur.
library;

/// Open Library / ağ isteklerinde oluşan hatalar.
class NetworkException implements Exception {
  const NetworkException(this.message, {this.cause});

  final String message;

  /// Yakalanan orijinal hata (loglama için; kullanıcıya gösterilmez).
  final Object? cause;

  @override
  String toString() => message;
}

/// Yerel depolama (SharedPreferences) okuma/yazma hataları.
class StorageException implements Exception {
  const StorageException(this.message, {this.cause});

  final String message;

  final Object? cause;

  @override
  String toString() => message;
}

class ApiConstants {
  const ApiConstants._();

  static const String baseUrl = 'https://openlibrary.org';
  static const String booksEndpoint = '/api/books';
  static const Duration timeout = Duration(seconds: 10);
}

class StorageKeys {
  const StorageKeys._();

  static const String books = 'books_v1';
}

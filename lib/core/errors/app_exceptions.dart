class NetworkException implements Exception {
  const NetworkException([this.message = 'Bağlantı hatası']);

  final String message;

  @override
  String toString() => message;
}

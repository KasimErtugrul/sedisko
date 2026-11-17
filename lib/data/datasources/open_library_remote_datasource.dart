import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';

class OpenLibraryRemoteDataSource {
  OpenLibraryRemoteDataSource(this._client);

  final http.Client _client;

  /// Kitap bulunamazsa `null`, ağ/sunucu sorununda [NetworkException] fırlatır.
  Future<Map<String, dynamic>?> fetchByIsbn(String isbn) async {
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    final key = 'ISBN:$cleanIsbn';

    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.booksEndpoint}')
        .replace(queryParameters: {
      'bibkeys': key,
      'format': 'json',
      'jscmd': 'data',
    });

    try {
      final response = await _client.get(uri).timeout(ApiConstants.timeout);
      if (response.statusCode != 200) {
        throw NetworkException('Sunucu hatası (${response.statusCode})');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded.isEmpty) return null;
      final data = decoded[key];
      if (data is! Map) return null;
      return Map<String, dynamic>.from(data);
    } on NetworkException {
      rethrow;
    } catch (_) {
      throw const NetworkException('İnternet bağlantısı kurulamadı');
    }
  }
}

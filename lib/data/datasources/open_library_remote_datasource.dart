import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/open_library_search_result.dart';

class OpenLibraryRemoteDataSource {
  OpenLibraryRemoteDataSource(this._client);

  final http.Client _client;

  /// Kitap bulunamazsa `null`, ağ/sunucu sorununda [NetworkException] fırlatır.
  Future<Map<String, dynamic>?> fetchByIsbn(String isbn) async {
    final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
    final key = 'ISBN:$cleanIsbn';

    final uri =
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.booksEndpoint}')
            .replace(queryParameters: {
      'bibkeys': key,
      'format': 'json',
      'jscmd': 'data',
    });

    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(ApiConstants.timeout);

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
    } on TimeoutException {
      throw const NetworkException(
        'Sunucu yanıt vermedi (zaman aşımı). Tekrar deneyin.',
      );
    } on FormatException catch (error) {
      throw NetworkException('Sunucudan geçersiz yanıt alındı', cause: error);
    } on http.ClientException catch (error) {
      throw NetworkException('İnternet bağlantısı kurulamadı', cause: error);
    } catch (error) {
      throw NetworkException(
        'İnternet bağlantısı kurulamadı',
        cause: error,
      );
    }
  }

  /// Başlık ve/veya yazarla Open Library araması (/search.json).
  ///
  /// İki alan da boşsa [ArgumentError] fırlatır. Ağ/sunucu sorununda
  /// [NetworkException]. Bozuk tek sonuç atlanır; geçerli sonuçlar
  /// [OpenLibrarySearchResult.tryFromJson] ile ayrıştırılır.
  Future<List<OpenLibrarySearchResult>> searchBooks({
    String? title,
    String? author,
    int limit = 20,
  }) async {
    final cleanTitle = title?.trim() ?? '';
    final cleanAuthor = author?.trim() ?? '';
    if (cleanTitle.isEmpty && cleanAuthor.isEmpty) {
      throw ArgumentError.value(
        null,
        'title/author',
        'Başlık ve yazar en az biri dolu olmalı.',
      );
    }

    // Boş parametreler URI'ye konmaz; dolu alanlar tam eşleşme olarak
    // gider (Open Library /search.json `title` ve `author` parametreleri).
    final uri = Uri.parse('${ApiConstants.baseUrl}/search.json').replace(
      queryParameters: <String, String>{
        'fields':
            'key,title,author_name,first_publish_year,cover_i,isbn,number_of_pages_median,publisher',
        'limit': limit.toString(),
        if (cleanTitle.isNotEmpty) 'title': cleanTitle,
        if (cleanAuthor.isNotEmpty) 'author': cleanAuthor,
      },
    );

    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(ApiConstants.timeout);

      if (response.statusCode != 200) {
        throw NetworkException('Sunucu hatası (${response.statusCode})');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return [];
      final docs = decoded['docs'];
      if (docs is! List) return [];

      final results = <OpenLibrarySearchResult>[];
      for (final doc in docs) {
        if (doc is! Map) continue;
        final result = OpenLibrarySearchResult.tryFromJson(
          Map<String, dynamic>.from(doc),
        );
        if (result != null) results.add(result);
      }
      return results;
    } on NetworkException {
      rethrow;
    } on TimeoutException {
      throw const NetworkException(
        'Sunucu yanıt vermedi (zaman aşımı). Tekrar deneyin.',
      );
    } on FormatException catch (error) {
      throw NetworkException('Sunucudan geçersiz yanıt alındı', cause: error);
    } on http.ClientException catch (error) {
      throw NetworkException('İnternet bağlantısı kurulamadı', cause: error);
    } catch (error) {
      throw NetworkException(
        'İnternet bağlantısı kurulamadı',
        cause: error,
      );
    }
  }
}

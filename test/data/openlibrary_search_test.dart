import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kitaplik/core/errors/app_exceptions.dart';
import 'package:kitaplik/data/datasources/open_library_remote_datasource.dart';

/// searchBooks: URL/query üretimi, docs ayrıştırma, bozuk sonuç atlama,
/// ArgumentError ve NetworkException davranışı (1.18.0).
void main() {
  late http.Request? lastRequest;
  late OpenLibraryRemoteDataSource dataSource;

  setUp(() {
    lastRequest = null;
    dataSource = OpenLibraryRemoteDataSource(
      MockClient((request) async {
        lastRequest = request;
        return http.Response(
          jsonEncode({
            'docs': [
              {
                'key': '/works/OL1',
                'title': 'Dune',
                'author_name': ['Frank Herbert'],
                'first_publish_year': 1965,
                'cover_i': 846192,
                'isbn': ['0140328726', '9780140328721'],
                'number_of_pages_median': 412,
                'publisher': ['Chilton Books', 'Ace Books'],
              },
              {
                'key': '/works/OL2',
                'title': 'Kürk Mantolu Madonna',
                'author_name': ['Sabahattin Ali'],
                'first_publish_year': 1943,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  group('URL ve sorgu parametreleri', () {
    test('başlık araması doğru URL/query üretir', () async {
      final results = await dataSource.searchBooks(title: 'Dune');

      final request = lastRequest!;
      expect(request.url.host, 'openlibrary.org');
      expect(request.url.path, '/search.json');
      expect(request.url.queryParameters['title'], 'Dune');
      expect(request.url.queryParameters['limit'], '20');
      expect(
        request.url.queryParameters['fields'],
        'key,title,author_name,first_publish_year,cover_i,isbn,'
        'number_of_pages_median,publisher',
      );
      // Dolu olmayan parametre URI'ye konmaz.
      expect(request.url.queryParameters.containsKey('author'), isFalse);
      expect(results.map((r) => r.title), ['Dune', 'Kürk Mantolu Madonna']);
    });

    test('iki alan doluysa ikisi de gönderilir', () async {
      await dataSource.searchBooks(title: 'Sinekli', author: 'Halide Edip');

      expect(lastRequest!.url.queryParameters['title'], 'Sinekli');
      expect(lastRequest!.url.queryParameters['author'], 'Halide Edip');
    });

    test('limit override edilir', () async {
      await dataSource.searchBooks(title: 'Dune', limit: 5);
      expect(lastRequest!.url.queryParameters['limit'], '5');
    });
  });

  group('docs ayrıştırma', () {
    test('alanlar modele taşınır', () async {
      final results = await dataSource.searchBooks(title: 'Dune');
      final first = results.first;

      expect(first.authors, ['Frank Herbert']);
      expect(first.firstPublishYear, 1965);
      expect(first.coverId, 846192);
      expect(first.isbns, ['0140328726', '9780140328721']);
      expect(first.publishers, ['Chilton Books', 'Ace Books']);
      expect(first.pageCount, 412);
    });

    test('bozuk doc atlanır, geçerliler korunur', () async {
      // 'title' olmayan kayıt listeye alınmaz; tek bozuk sonuç tüm
      // aramayı bozmamalı.
      dataSource = OpenLibraryRemoteDataSource(
        MockClient((request) async => http.Response(
              jsonEncode({
                'docs': [
                  {'title': 'Sağlam Kitap'},
                  {'key': '/works/OLX', 'author_name': ['Titiziz']},
                  'yazı değil',
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            )),
      );

      final results = await dataSource.searchBooks(title: 'herhangi');
      expect(results.map((r) => r.title), ['Sağlam Kitap']);
    });

    test('docs yoksa/boşsa boş liste döner', () async {
      dataSource = OpenLibraryRemoteDataSource(
        MockClient((request) async => http.Response(
              jsonEncode({'docs': []}),
              200,
              headers: {'content-type': 'application/json'},
            )),
      );
      expect(await dataSource.searchBooks(title: 'yok'), isEmpty);

      dataSource = OpenLibraryRemoteDataSource(
        MockClient((request) async => http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            )),
      );
      expect(await dataSource.searchBooks(title: 'yok'), isEmpty);
    });
  });

  group('hata davranışı', () {
    test('iki alan boşsa ArgumentError fırlatır', () async {
      await expectLater(
        dataSource.searchBooks(),
        throwsArgumentError,
      );
      await expectLater(
        dataSource.searchBooks(title: '  ', author: ''),
        throwsArgumentError,
      );
      // İstek hiç gönderilmemeli.
      expect(lastRequest, isNull);
    });

    test('HTTP 500 NetworkException fırlatır', () async {
      dataSource = OpenLibraryRemoteDataSource(
        MockClient((request) async => http.Response('boom', 500)),
      );

      await expectLater(
        dataSource.searchBooks(title: 'Dune'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('bozuk JSON NetworkException fırlatır', () async {
      dataSource = OpenLibraryRemoteDataSource(
        MockClient((request) async => http.Response('[[[', 200)),
      );

      await expectLater(
        dataSource.searchBooks(title: 'Dune'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('ağ hatası (ClientException) NetworkException olur', () async {
      dataSource = OpenLibraryRemoteDataSource(
        MockClient((request) async => throw http.ClientException('koptu')),
      );

      await expectLater(
        dataSource.searchBooks(title: 'Dune'),
        throwsA(
          isA<NetworkException>()
              .having((e) => e.message, 'message', 'İnternet bağlantısı kurulamadı'),
        ),
      );
    });
  });

  test('fetchByIsbn davranışı korunur (regresyon)', () async {
    // searchBooks eklenirken mevcut ISBN akışı bozulmamalı.
    dataSource = OpenLibraryRemoteDataSource(
      MockClient((request) async {
        lastRequest = request;
        return http.Response(
          jsonEncode({
            'ISBN:9780140328721': {
              'title': 'Dune',
              'authors': [{'name': 'Frank Herbert'}],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final data = await dataSource.fetchByIsbn('9780140328721');
    expect(data, isNotNull);
    expect(data!['title'], 'Dune');
    expect(lastRequest!.url.path, '/api/books');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/core/errors/app_exceptions.dart';
import 'package:kitaplik/data/datasources/book_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late BookLocalDataSource dataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dataSource = BookLocalDataSource(prefs);
  });

  BookModel book(String id, {String title = 'Kitap', String? shelf}) =>
      BookModel(
        id: id,
        title: title,
        shelf: shelf ?? '',
        addedAt: DateTime(2024, 1, 1),
      );

  group('upsert', () {
    test('yeni kitap ekler', () async {
      await dataSource.upsert(book('1', title: 'Dune'));
      expect(dataSource.getBooks().map((b) => b.id), ['1']);
    });

    test('aynı id ile çağrılırsa üzerine yazar (upsert)', () async {
      await dataSource.upsert(book('1', title: 'Eski'));
      await dataSource.upsert(book('1', title: 'Yeni'));
      final books = dataSource.getBooks();
      expect(books.length, 1);
      expect(books.first.title, 'Yeni');
    });

    test('paralel çağrılar veri kaybettirmez (yazma kuyruğu)', () async {
      // Orijinal kodda: iki upsert aynı anda okuyup yazdığında biri
      // kayboluyordu. Sıraya alınmış yazma ile ikisi de kalıcı olmalı.
      await Future.wait([
        dataSource.upsert(book('1', title: 'Birinci')),
        dataSource.upsert(book('2', title: 'İkinci')),
        dataSource.upsert(book('3', title: 'Üçüncü')),
      ]);

      final books = dataSource.getBooks();
      expect(books.length, 3);
      expect(books.map((b) => b.title).toSet(),
          {'Birinci', 'İkinci', 'Üçüncü'});
    });
  });

  group('delete', () {
    test('kitabı siler', () async {
      await dataSource.upsert(book('1'));
      await dataSource.upsert(book('2'));
      await dataSource.delete('1');

      expect(dataSource.getBooks().map((b) => b.id), ['2']);
    });

    test('olmayan id silme isteği hatasız geçer', () async {
      await dataSource.upsert(book('1'));
      await dataSource.delete('yok');
      expect(dataSource.getBooks().length, 1);
    });
  });

  group('bozuk veri dayanıklılığı', () {
    test('tamamen bozuk JSON bloğu için boş liste döner', () async {
      await prefs.setString('books_v1', '[[[bu-json-degil');
      expect(dataSource.getBooks(), isEmpty);
    });

    test('tek bozuk kayıt diğerlerini silmez', () async {
      // Orijinal kodda: tek bozuk kayıt tüm listeyi [] yapıyordu ve bir
      // sonraki yazma kalan kitapları kalıcı olarak yok ediyordu.
      const corrupted = '''
      [
        {"id": "1", "title": "Sağlam Kitap"},
        {"title": "idsiz bozuk kayıt"},
        {"id": "2", "title": "İkinci Sağlam", "pageCount": 300}
      ]
      ''';
      await prefs.setString('books_v1', corrupted);

      final books = dataSource.getBooks();
      expect(books.map((b) => b.id).toList(), ['1', '2']);
      expect(books.first.title, 'Sağlam Kitap');
      expect(books.last.pageCount, 300);
    });

    test('kök liste değil Map gelseydi boş liste döner', () async {
      await prefs.setString('books_v1', '{"id": "1"}');
      expect(dataSource.getBooks(), isEmpty);
    });
  });

  group('yazma hataları', () {
    test('yazma başarısızsa StorageException fırlatır', () async {
      // Mock SharedPreferences setString false dönebilir; datasource bunu
      // StorageException'a çevirmelidir ki üst katman haberdar olsun.
      final failingSource = BookLocalDataSource(_FailingPrefs(prefs));

      await expectLater(
        failingSource.upsert(book('1')),
        throwsA(isA<StorageException>()),
      );
    });
  });
}

/// Sadece test için: setString'i false dönen SharedPreferences sarmalayıcı.
class _FailingPrefs implements SharedPreferences {
  _FailingPrefs(this._inner);

  final SharedPreferences _inner;

  @override
  Future<bool> setString(String key, String value) async => false;

  // Kalan üyeler iç sarmalayıcıya devredilir.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #getString
          ? _inner.getString(invocation.positionalArguments[0] as String)
          : super.noSuchMethod(invocation);
}

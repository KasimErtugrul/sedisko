import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/datasources/book_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

BookModel book(String id, String title) => BookModel(
      id: id,
      title: title,
      addedAt: DateTime(2026, 1, 1),
    );

/// Yedek içe aktarımının kullandığı toplu yazma metodları
/// ([BookLocalDataSource.addMany], [BookLocalDataSource.replaceAll]).
void main() {
  late SharedPreferences prefs;
  late BookLocalDataSource dataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dataSource = BookLocalDataSource(prefs);
  });

  test('addMany kitapları tek yazmada ekler', () async {
    await dataSource.upsert(book('1', 'Var olan'));
    await dataSource.addMany([book('2', 'Yeni bir'), book('3', 'Yeni iki')]);

    final books = dataSource.getBooks();
    expect(books.map((b) => b.id), ['1', '2', '3']);
  });

  test('addMany boş liste yazmaya dokunmaz', () async {
    await dataSource.upsert(book('1', 'Var olan'));
    await dataSource.addMany([]);
    expect(dataSource.getBooks().map((b) => b.id), ['1']);
  });

  test('replaceAll mevcut listeyi komple değiştirir', () async {
    await dataSource.upsert(book('1', 'Eski'));
    await dataSource.upsert(book('2', 'Eski iki'));
    await dataSource.replaceAll([book('9', 'Yedekten')]);

    final books = dataSource.getBooks();
    expect(books.map((b) => b.id), ['9']);
  });

  test('replaceAll ile paralel upsert birbirini kaybettirmez', () async {
    await dataSource.upsert(book('1', 'Eski'));
    await Future.wait([
      dataSource.replaceAll([book('9', 'Yedekten')]),
      dataSource.upsert(book('8', 'Paralel')),
    ]);

    final ids = dataSource.getBooks().map((b) => b.id).toSet();
    // Sıra önemli değildir; iki işlem de kaybolmadan uygulanmalıdır.
    expect(ids.contains('9'), isTrue, reason: 'replaceAll uygulanmalı');
    expect(ids.contains('8'), isTrue, reason: 'upsert kaybolmamalı');
  });
}

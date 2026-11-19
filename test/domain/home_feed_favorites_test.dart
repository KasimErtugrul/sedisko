import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/services/home_feed.dart';

/// Favori yazar özetlerinin saf servisi (1.16.0).
///
/// Kullanıcının sıraladığı favori yazar listesi kitaplıkla birleşir:
/// kitap sayısı hesaplanır, yazım çeşitleri tek kartta toplanır, kitabı
/// olmayan favori yazar da listede kalır.
BookModel bookWithAuthors(String id, List<String> authors) => BookModel(
      id: id,
      title: 'Kitap $id',
      authors: authors,
      shelf: 'Raf',
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('favori yazarlar kullanıcının sırasıyla döner', () {
    final books = [
      bookWithAuthors('b1', ['Ahmet Ümit']),
      bookWithAuthors('b2', ['Ahmet Ümit', 'Ayşe Kulin']),
      bookWithAuthors('b3', ['Ayşe Kulin']),
    ];

    final summaries = HomeFeed.favoriteAuthorSummaries(
      books,
      ['Ayşe Kulin', 'Ahmet Ümit'],
    );

    // Kullanıcının sırası korunur (kitap sayısı sıralaması DEĞİL).
    expect(summaries.map((s) => s.name).toList(),
        ['Ayşe Kulin', 'Ahmet Ümit']);
    expect(summaries[0].bookCount, 2);
    expect(summaries[1].bookCount, 2);
  });

  test('kitabı olmayan favori yazar listede kalır, sayısı 0', () {
    final books = [bookWithAuthors('b1', ['Ahmet Ümit'])];

    final summaries = HomeFeed.favoriteAuthorSummaries(
      books,
      ['Orhan Pamuk'],
    );

    expect(summaries, hasLength(1));
    expect(summaries.single.name, 'Orhan Pamuk');
    expect(summaries.single.bookCount, 0);
  });

  test('yazım çeşitleri tek kartta toplanır ve ilk yazım görünür', () {
    // Open Library "Kasım"ı sadeleştirip "Kasim" yazabilir; ikisi aynı
    // gruba katlanır. Kullanıcı "kasim" yazsa bile kart birleşir.
    final books = [
      bookWithAuthors('b1', ['Kasım']),
      bookWithAuthors('b2', ['Kasim']),
    ];

    final summaries = HomeFeed.favoriteAuthorSummaries(
      books,
      ['kasim'],
    );

    expect(summaries, hasLength(1));
    expect(summaries.single.key, 'kasim');
    expect(summaries.single.name, 'Kasım'); // kitaplıktaki ilk yazım
    expect(summaries.single.bookCount, 2);
  });

  test('favori listesindeki yinelenen yazımlar tek kartta birleşir', () {
    final books = [bookWithAuthors('b1', ['Ahmet Ümit'])];

    final summaries = HomeFeed.favoriteAuthorSummaries(
      books,
      ['Ahmet Ümit', 'ahmet ümit', 'AHMET ÜMIT'],
    );

    expect(summaries, hasLength(1));
    expect(summaries.single.bookCount, 1);
  });

  test('boş favori listesi boş özet verir', () {
    final books = [bookWithAuthors('b1', ['Ahmet Ümit'])];

    expect(HomeFeed.favoriteAuthorSummaries(books, []), isEmpty);
  });
}

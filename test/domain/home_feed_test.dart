import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/services/home_feed.dart';

BookModel book({
  required String id,
  String title = 'Kitap',
  List<String> authors = const [],
  DateTime? addedAt,
  ReadingStatus status = ReadingStatus.notStarted,
  DateTime? finishedAt,
}) {
  return BookModel(
    id: id,
    title: title,
    authors: authors,
    addedAt: addedAt ?? DateTime(2026, 1, 1),
    status: status,
    finishedAt: finishedAt,
  );
}

void main() {
  group('HomeFeed.topAuthors', () {
    test('kitap sayısı azalan sıralar ve yazım çeşitlerini tek grupta toplar',
        () {
      final books = [
        book(id: 'b1', authors: ['Orhan Pamuk']),
        book(id: 'b2', authors: ['Orhan Pamuk']),
        book(id: 'b3', authors: ['Orhan Pamuk']),
        // "Kasım" ve "Kasim" aynı arama anahtarına katlanır: tek grup.
        book(id: 'b4', authors: ['Kasım']),
        book(id: 'b5', authors: ['Kasim']),
      ];

      final top = HomeFeed.topAuthors(books);

      expect(top.length, 2);
      expect(top[0].name, 'Orhan Pamuk');
      expect(top[0].bookCount, 3);
      // Görünen ad ilk görülen yazımdır.
      expect(top[1].name, 'Kasım');
      expect(top[1].bookCount, 2);
    });

    test('eşitlikte Türkçe alfabe sırasına göre sıralar', () {
      final books = [
        book(id: 'b1', authors: ['Zeynep']),
        book(id: 'b2', authors: ['Ali']),
        book(id: 'b3', authors: ['Çetin']),
      ];

      final names = HomeFeed.topAuthors(books).map((a) => a.name).toList();

      expect(names, ['Ali', 'Çetin', 'Zeynep']);
    });

    test('limit dışındaki yazarlar elenir', () {
      final books = [
        for (var i = 0; i < 12; i++) book(id: 'b$i', authors: ['Yazar $i']),
      ];

      expect(HomeFeed.topAuthors(books).length, 10);
      expect(HomeFeed.topAuthors(books, limit: 3).length, 3);
    });

    test('boş ve yalnız boşluklu yazarlar sayılmaz', () {
      final books = [
        book(id: 'b1', authors: ['', '   ']),
        book(id: 'b2', authors: const []),
      ];

      expect(HomeFeed.topAuthors(books), isEmpty);
    });
  });

  group('HomeFeed.recentlyAdded', () {
    test('en yeni kitap başa gelir', () {
      final books = [
        book(id: 'b1', title: 'Eski', addedAt: DateTime(2026, 3, 1)),
        book(id: 'b2', title: 'Yeni', addedAt: DateTime(2026, 3, 10)),
        book(id: 'b3', title: 'Orta', addedAt: DateTime(2026, 3, 5)),
      ];

      final titles =
          HomeFeed.recentlyAdded(books).map((b) => b.title).toList();

      expect(titles, ['Yeni', 'Orta', 'Eski']);
    });

    test('aynı tarihte Türkçe kitap adı sırası kullanılır', () {
      final books = [
        book(id: 'b1', title: 'Şeker Portakalı', addedAt: DateTime(2026, 3, 1)),
        book(id: 'b2', title: 'Simyacı', addedAt: DateTime(2026, 3, 1)),
        book(id: 'b3', title: 'Dönüşüm', addedAt: DateTime(2026, 3, 1)),
      ];

      final titles =
          HomeFeed.recentlyAdded(books).map((b) => b.title).toList();

      expect(titles, ['Dönüşüm', 'Simyacı', 'Şeker Portakalı']);
    });

    test('limit dışındakiler elenir', () {
      final books = [
        for (var i = 0; i < 14; i++)
          book(id: 'b$i', title: 'Kitap $i', addedAt: DateTime(2026, 1, i + 1)),
      ];

      expect(HomeFeed.recentlyAdded(books).length, 10);
      // En yeni başta: 2026-01-14 ilk sırada.
      expect(HomeFeed.recentlyAdded(books).first.title, 'Kitap 13');
    });
  });

  group('HomeFeed.finishedThisMonth', () {
    test('bu ay bitirilenleri en yeni bitişten geriye sıralar', () {
      final books = [
        book(
          id: 'b1',
          title: 'Ay Başı',
          status: ReadingStatus.finished,
          finishedAt: DateTime(2026, 5, 3),
        ),
        book(
          id: 'b2',
          title: 'Ay Sonu',
          status: ReadingStatus.finished,
          finishedAt: DateTime(2026, 5, 28),
        ),
      ];

      final titles = HomeFeed.finishedThisMonth(books, DateTime(2026, 5, 15))
          .map((b) => b.title)
          .toList();

      expect(titles, ['Ay Sonu', 'Ay Başı']);
    });

    test('ayın ilk günü dahildir, bir önceki ay hariçtir', () {
      final books = [
        book(
          id: 'b1',
          title: 'Bir Mayıs',
          status: ReadingStatus.finished,
          finishedAt: DateTime(2026, 5, 1),
        ),
        book(
          id: 'b2',
          title: 'Nisan Sonu',
          status: ReadingStatus.finished,
          finishedAt: DateTime(2026, 4, 30, 23, 59),
        ),
      ];

      final titles = HomeFeed.finishedThisMonth(books, DateTime(2026, 5, 15))
          .map((b) => b.title)
          .toList();

      expect(titles, ['Bir Mayıs']);
    });

    test('bitiş tarihi olmayan bitti kayıtları şeride girmez', () {
      final books = [
        book(id: 'b1', title: 'Tarihsiz', status: ReadingStatus.finished),
        book(
          id: 'b2',
          title: 'Okunuyor',
          status: ReadingStatus.reading,
          finishedAt: DateTime(2026, 5, 2),
        ),
      ];

      expect(
        HomeFeed.finishedThisMonth(books, DateTime(2026, 5, 15)),
        isEmpty,
      );
    });

    test('yıl sınırı güvenlidir: aralık bir sonraki yıla taşınır', () {
      final books = [
        book(
          id: 'b1',
          title: 'Aralık Sonu',
          status: ReadingStatus.finished,
          finishedAt: DateTime(2026, 12, 31),
        ),
        book(
          id: 'b2',
          title: 'Ocak Başı',
          status: ReadingStatus.finished,
          finishedAt: DateTime(2027, 1, 1),
        ),
      ];

      final titles = HomeFeed.finishedThisMonth(books, DateTime(2026, 12, 15))
          .map((b) => b.title)
          .toList();

      expect(titles, ['Aralık Sonu']);
    });
  });
}

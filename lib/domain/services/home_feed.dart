import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';

/// Ana sayfa yazar şeridinin tek kartı: bir yazar grubunun görünen adı,
/// arama anahtarı ve kitap sayısı.
///
/// [key], [TextNormalizer.searchKey] ile üretilir; "Kasım" ve "Kasim"
/// yazımları aynı anahtara katlandığı için tek kartta toplanır.
/// [name], gruptaki ilk görülen yazımdır.
class AuthorSummary {
  const AuthorSummary({
    required this.key,
    required this.name,
    required this.bookCount,
  });

  final String key;
  final String name;
  final int bookCount;
}

/// Ana sayfa bölümlerinin verisini üreten saf servis.
///
/// GetX'e ve arayüze bağımlı değildir: kitap listesini alır, sıralı liste
/// döner. [LibraryController] bu servise ince sorgularla girmek yerine
/// mevcut sorgularını korur; ana sayfa yeni bölümlerini buradan besler.
/// Böylece toplanma kuralları arayüzden bağımsız test edilir.
class HomeFeed {
  const HomeFeed._();

  /// En çok kitaba sahip yazarlar ("En çok kitaba sahip yazarlar" şeridi).
  ///
  /// Kurallar:
  /// - Kitap sayısı azalan; eşitlikte görünen ad Türkçe alfabe sırasıyla,
  ///   o da eşitse anahtar sırasıyla (kararlı liste).
  /// - Boş yazar bilgisi sayılmaz.
  /// - [limit] en çok bu kadar kart döner (şerit taşmasın).
  static List<AuthorSummary> topAuthors(
    List<BookModel> books, {
    int limit = 10,
  }) {
    final nameByKey = <String, String>{};
    final countByKey = <String, int>{};

    for (final book in books) {
      for (final raw in book.authors) {
        final author = raw.trim();
        if (author.isEmpty) continue;
        final key = TextNormalizer.searchKey(author);
        nameByKey.putIfAbsent(key, () => author);
        countByKey[key] = (countByKey[key] ?? 0) + 1;
      }
    }

    final entries = countByKey.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        final byName = TextNormalizer.compareTr(nameByKey[a.key]!,
            nameByKey[b.key]!);
        if (byName != 0) return byName;
        return a.key.compareTo(b.key);
      });

    return entries
        .take(limit)
        .map(
          (entry) => AuthorSummary(
            key: entry.key,
            name: nameByKey[entry.key]!,
            bookCount: entry.value,
          ),
        )
        .toList();
  }

  /// Son eklenen kitaplar ("Son eklenenler" şeridi).
  ///
  /// Eklenme tarihi azalan; eşitlikte kitap adı (Türkçe), o da eşitse id.
  /// Eski kayıtlarda `addedAt` yoksa ayrıştırma bugüne düşer (BookModel),
  /// yine de bu şeritte birincil sıra tarihtır.
  static List<BookModel> recentlyAdded(
    List<BookModel> books, {
    int limit = 10,
  }) {
    final list = books.toList()
      ..sort((a, b) {
        final byDate = b.addedAt.compareTo(a.addedAt);
        if (byDate != 0) return byDate;
        final byTitle = TextNormalizer.compareTr(a.title, b.title);
        if (byTitle != 0) return byTitle;
        return a.id.compareTo(b.id);
      });
    return list.take(limit).toList();
  }

  /// [from] (dahil) ile [to] (hariç) arasında bitirilen kitaplar; en yeni
  /// bitiş önce.
  ///
  /// Yalnız `finished` durumundaki ve bitiş tarihi bilinen kitaplar sayılır:
  /// bitiş tarihi elle girilmemiş eski "bitti" kayıtları bu şeride girmek
  /// yerine sessizce dışarıda kalır (yanlış ay listelemek yerine).
  static List<BookModel> finishedBetween(
    List<BookModel> books,
    DateTime from,
    DateTime to,
  ) {
    final list = books.where((book) {
      if (book.status != ReadingStatus.finished) return false;
      final finishedAt = book.finishedAt;
      if (finishedAt == null) return false;
      return !finishedAt.isBefore(from) && finishedAt.isBefore(to);
    }).toList()
      ..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));
    return list;
  }

  /// Bu ay bitirilen kitaplar ("Bu ay bitirdiklerin" şeridi).
  ///
  /// Ay sınırı 1. gün 00:00'dan bir sonraki ayın 1. gününe kadardır; Dart
  /// 13. ayı bir sonraki yıla taşır, aralık sınırı güvenlidir.
  static List<BookModel> finishedThisMonth(
    List<BookModel> books,
    DateTime now,
  ) {
    final from = DateTime(now.year, now.month);
    final to = DateTime(now.year, now.month + 1);
    return finishedBetween(books, from, to);
  }
}

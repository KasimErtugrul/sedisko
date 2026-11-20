/// Open Library başlık/yazar araması (/search.json) tek sonuç kaydı.
///
/// 1.18.0: ISBN aramasının yanına isim/yazarla arama eklendi. Arama
/// uç noktası ISBN uç noktasından farklı bir belge biçimi döndürür
/// (`author_name`, `cover_i`, `number_of_pages_median` ...); bu model o
/// biçimin savunmacı ayrıştırıcısıdır ve `BookModel`'e dönüştürerek
/// mevcut form akışına beslenmesini sağlar.
library;

import 'book_model.dart';

class OpenLibrarySearchResult {
  const OpenLibrarySearchResult({
    required this.title,
    this.authors = const [],
    this.firstPublishYear,
    this.coverId,
    this.isbns = const [],
    this.publishers = const [],
    this.pageCount,
  });

  final String title;
  final List<String> authors;

  /// İlk yayın yılı (`first_publish_year`).
  final int? firstPublishYear;

  /// Kapak görseli kimliği (`cover_i`).
  final int? coverId;

  /// Open Library'nin döndürdüğü ISBN'ler (10 ve 13 haneli karışık).
  final List<String> isbns;
  final List<String> publishers;

  /// Tahmini sayfa sayısı (`number_of_pages_median`).
  final int? pageCount;

  /// Kapak URL'si (orta boy); kapak yoksa `null`.
  String? get coverUrl =>
      coverId == null ? null : 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';

  /// Arama cevabındaki tek `docs` kaydını ayrıştırır.
  ///
  /// `title` boş olmayan bir String olmak zorundadır; diğer alanlar
  /// savunmacı okunur (liste/int beklenmedik tipte gelirse varsayılana
  /// düşer). [title] geçersizse `null` döner ve sonuç listede atlanır.
  static OpenLibrarySearchResult? tryFromJson(Map<String, dynamic> json) {
    final title = json['title'];
    if (title is! String || title.isEmpty) return null;

    return OpenLibrarySearchResult(
      title: title,
      authors: _stringList(json['author_name']),
      firstPublishYear: _asInt(json['first_publish_year']),
      coverId: _asInt(json['cover_i']),
      isbns: _stringList(json['isbn']),
      publishers: _stringList(json['publisher']),
      pageCount: _asInt(json['number_of_pages_median']),
    );
  }

  /// Sonucu doldurulmuş bir kitap formuna ([BookFormArgs]) taşınabilecek
  /// [BookModel]'e dönüştürür. Yeni kimlik üretilir; ISBN tercihen
  /// 13 haneli olanıdır ([_pickIsbn]).
  BookModel toBook() {
    return BookModel(
      id: BookModel.newId(),
      title: title,
      authors: authors,
      isbn: _pickIsbn(),
      coverUrl: coverUrl,
      publisher: publishers.isNotEmpty ? publishers.first : null,
      publishDate: firstPublishYear?.toString(),
      pageCount: pageCount ?? 0,
      addedAt: DateTime.now(),
    );
  }

  /// Tercihen 13 haneli (yalnız rakam) ilk ISBN; yoksa ilk ISBN,
  /// hiç ISBN yoksa `null`.
  String? _pickIsbn() {
    for (final isbn in isbns) {
      if (isbn.length == 13 && _isbn13.hasMatch(isbn)) return isbn;
    }
    return isbns.isEmpty ? null : isbns.first;
  }

  static final RegExp _isbn13 = RegExp(r'^\d{13}$');

  /// Open Library bazen liste yerine String/null döndürebilir; savunmacı
  /// dönüştürme: List → String listesi, boşlar atılır.
  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<Object>()
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  /// `as num?` String girdide TypeError fırlatır; savunmacı dönüşüm gerekli.
  static int? _asInt(Object? value) => value is num ? value.toInt() : null;
}

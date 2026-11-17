import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';

/// Kitap listelerinin sıralanabilmesi için alanlar.
///
/// Etiketler doğrudan sıralama alt sayfasında gösterilir; kullanıcı
/// isteğiyle gelen alanlar (sayfa sayısı, yazar, yayınevi, raf, okunulan
/// sayfa, başlama/bitiş tarihi, basım tarihi) ve varsayılan kitap adı.
enum BookSortField {
  title('Kitap adı'),
  author('Yazar'),
  publisher('Yayınevi'),
  shelf('Raf adı'),
  pageCount('Sayfa sayısı'),
  currentPage('Okunulan sayfa'),
  startedAt('Başlama tarihi'),
  finishedAt('Bitirme tarihi'),
  publishDate('Basım tarihi');

  const BookSortField(this.label);

  final String label;
}

/// Kitap listelerini aktif alana ve yöne göre sıralayan saf servis.
///
/// Kurallar:
/// - **Eksik bilgi her iki yönde de sona gider.** "Bitirme tarihi azalan"
///   seçiminde bitmemiş kitaplar listenin başına fırlamaz; bilinen
///   tarihler sıralanır, tarihsizler sonda bekler. Eksik tanımı alan
///   başına yapılır: sayfa sayısı 0, boş metin ve `null` tarih eksiktir;
///   okunulan sayfa 0 ise gerçek bir değerdir ("başlamadı").
/// - **Türkçe alfabe:** metin alanları `TextNormalizer.compareTr` ile
///   karşılaştırılır (ç/ğ/ı/ö/ş/ü ASCII sonrasına değil alfabeye göre).
/// - **Basım tarihi yıl bazlıdır:** Open Library tarihleri serbest metin
///   olduğu için ("October 1, 2005", "2005") 19xx/20xx yılı ayıklanır;
///   aynı yılda kalanlar metin sırasıyla ayrıştırılır.
/// - **Kararlı sonuç:** birincil alan eşitse kitap adı, o da eşitse id
///   karşılaştırılır; böylece her çağrıda aynı sıra üretilir.
abstract final class BookSorter {
  const BookSorter._();

  /// [books] listesini yerinde sıralar; [ascending] `false` ise azalan.
  static void sort(
    List<BookModel> books,
    BookSortField field,
    bool ascending,
  ) {
    books.sort((a, b) => compare(a, b, field, ascending));
  }

  /// İki kitabı [field] ve [ascending] yönüne göre karşılaştırır.
  /// `List.sort` karşılaştırıcısının gerektirdiği tutarlılık burada
  /// korunur: eksiklik kontrolleri yön ters çevrilmeden önce yapılır.
  static int compare(
    BookModel a,
    BookModel b,
    BookSortField field,
    bool ascending,
  ) {
    // Eksik bilgi önce işaretlenir; yön ters çevirmek eksikleri başa
    // almasın diye eksiklik sıralaması bağımsız uygulanır.
    final missingA = isMissing(a, field);
    final missingB = isMissing(b, field);
    if (missingA != missingB) return missingA ? 1 : -1;
    if (missingA && missingB) return _tiebreak(a, b);

    final result = _presentCompare(a, b, field);
    if (result != 0) return ascending ? result : -result;
    return _tiebreak(a, b);
  }

  /// [book] için [field] bilgisinin eksik olup olmadığı.
  static bool isMissing(BookModel book, BookSortField field) {
    switch (field) {
      case BookSortField.title:
        return book.title.trim().isEmpty;
      case BookSortField.author:
        return book.authors.every((a) => a.trim().isEmpty);
      case BookSortField.publisher:
        return (book.publisher ?? '').trim().isEmpty;
      case BookSortField.shelf:
        return book.shelf.trim().isEmpty;
      case BookSortField.pageCount:
        return book.pageCount <= 0; // 0 = "bilinmiyor" (formda boş bırakılır)
      case BookSortField.currentPage:
        return false; // 0 gerçek bir değerdir: kitaba başlanmadı
      case BookSortField.startedAt:
        return book.startedAt == null;
      case BookSortField.finishedAt:
        return book.finishedAt == null;
      case BookSortField.publishDate:
        return _publishYear(book.publishDate ?? '') == null;
    }
  }

  /// Eksik olmayan iki değerin alan bazlı karşılaştırması.
  static int _presentCompare(BookModel a, BookModel b, BookSortField field) {
    switch (field) {
      case BookSortField.title:
        return TextNormalizer.compareTr(a.title, b.title);
      case BookSortField.author:
        return TextNormalizer.compareTr(_firstAuthor(a), _firstAuthor(b));
      case BookSortField.publisher:
        return TextNormalizer.compareTr(
          (a.publisher ?? '').trim(),
          (b.publisher ?? '').trim(),
        );
      case BookSortField.shelf:
        return TextNormalizer.compareTr(a.shelf.trim(), b.shelf.trim());
      case BookSortField.pageCount:
        return a.pageCount.compareTo(b.pageCount);
      case BookSortField.currentPage:
        return a.currentPage.compareTo(b.currentPage);
      case BookSortField.startedAt:
        return (a.startedAt ?? DateTime(0)).compareTo(b.startedAt ?? DateTime(0));
      case BookSortField.finishedAt:
        return (a.finishedAt ?? DateTime(0))
            .compareTo(b.finishedAt ?? DateTime(0));
      case BookSortField.publishDate:
        return _publishDateCompare(
          a.publishDate ?? '',
          b.publishDate ?? '',
        );
    }
  }

  /// Birincil alan eşitse listeyi her çağrıda aynı düzende vermek için
  /// ikincil anahtar: kitap adı, o da eşitse id.
  static int _tiebreak(BookModel a, BookModel b) {
    final byTitle = TextNormalizer.compareTr(a.title, b.title);
    if (byTitle != 0) return byTitle;
    return a.id.compareTo(b.id);
  }

  /// Çok yazarlı kitaplarda sıralama birincil (ilk) yazara göredir.
  static String _firstAuthor(BookModel book) {
    for (final author in book.authors) {
      final trimmed = author.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static final RegExp _yearPattern = RegExp(r'(?:19|20)\d{2}');

  /// Serbest metin basım tarihinden sıralama yılı; yoksa `null`.
  static int? _publishYear(String raw) {
    final match = _yearPattern.firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  /// Yıl birincil; aynı yılda kalanlar ("2005" vs "Mayıs 2005") metin
  /// sırasıyla ayrıştırılır.
  static int _publishDateCompare(String a, String b) {
    final yearA = _publishYear(a);
    final yearB = _publishYear(b);
    if (yearA != null && yearB != null && yearA != yearB) {
      return yearA.compareTo(yearB);
    }
    return TextNormalizer.compareTr(a, b);
  }
}

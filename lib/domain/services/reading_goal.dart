import '../../data/models/book_model.dart';

/// Bitirme hedefi hesapları: hedefe kalan takvim günü, günde okunması
/// gereken sayfa ve gecikme durumu.
///
/// Tüm fonksiyonlar saf ve saat bağımlılığı enjekte edilebilirdir:
/// uygulama `DateTime.now()` verir, testler sabit saat verir. Gün
/// karşılaştırmaları takvim günü bazlıdır (saat/dakika farkı sonucu
/// değiştirmez); böylece testler günün hangi saatinde çalıştırılırsa
/// çalıştırılsın aynı sonucu verir.
abstract final class ReadingGoal {
  /// [target] ile [now] arasındaki takvim günü farkı.
  ///
  /// Hedef bugünse 0, gelecekteyse pozitif ("kaç gün kaldı"), geçmişse
  /// negatif ("kaç gün gecikti") döner. Saat bileşenleri sıfırlanır:
  /// 23:50'den ertesi gün 00:10'a geçiş 1 gün sayılır, 0 değil.
  static int daysLeft(DateTime target, DateTime now) {
    final t = DateTime(target.year, target.month, target.day);
    final n = DateTime(now.year, now.month, now.day);
    return t.difference(n).inDays;
  }

  /// Hedefe yetişmek için günde okunması gereken sayfa (yukarı
  /// yuvarlanmış). Hesaplanamıyorsa `null` döner:
  /// - hedef konmamışsa,
  /// - kitap bitmişse,
  /// - sayfa sayısı bilinmiyorsa,
  /// - kalan sayfa kalmadıysa (zaten hedef sayfada/bitti),
  /// - hedef tarihi geçmişse (gecikme metni gösterilir, günlük plan
  ///   anlamını yitirir).
  static int? pagesPerDay(BookModel book, DateTime now) {
    final target = book.targetFinishDate;
    if (target == null) return null;
    if (book.status == ReadingStatus.finished) return null;
    if (book.pageCount <= 0) return null;
    final remaining = book.pageCount - book.currentPage;
    if (remaining <= 0) return null;
    final days = daysLeft(target, now);
    if (days <= 0) return null;
    return (remaining / days).ceil();
  }

  /// Kitap bitmemişken hedef tarihi geçmiş mi?
  static bool isOverdue(BookModel book, DateTime now) {
    final target = book.targetFinishDate;
    if (target == null) return false;
    if (book.status == ReadingStatus.finished) return false;
    return daysLeft(target, now) < 0;
  }

  /// Bitmiş kitapta hedefe göre sonuç, takvim günü farkı olarak:
  /// pozitif = hedeften kaç gün ÖNCE bitildi, negatif = hedef kaç gün
  /// aşıldı, 0 = tam gününde bitildi. Hedef yoksa ya da kitap bitmemişse
  /// `null`.
  static int? finishedAgainstTarget(BookModel book) {
    final target = book.targetFinishDate;
    if (target == null) return null;
    if (book.status != ReadingStatus.finished) return null;
    return daysLeft(target, book.finishedAt ?? DateTime.now());
  }
}

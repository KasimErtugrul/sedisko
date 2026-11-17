/// ISBN doğrulama ve temizleme yardımcıları.
///
/// ISBN-10 (mod 11, 'X' kontrol hanesi dahil) ve ISBN-13 (mod 10)
/// kontrol hanesi hesaplamalarını destekler.
library;

class IsbnValidator {
  const IsbnValidator._();

  static final RegExp _dirtyChars = RegExp(r'[^0-9Xx]');

  /// Tire, boşluk vb. ayırıcıları temizler. ISBN-10'un son hanesi
  /// olabilen `x`/`X` korunur.
  static String clean(String raw) => raw.replaceAll(_dirtyChars, '');

  /// [clean] çıktısı üzerinde kontrol hanesi doğrulaması yapar.
  ///
  /// Uzunluk 10 → ISBN-10, 13 → ISBN-13 kurallarına göre kontrol edilir.
  /// Diğer uzunluklar geçersizdir.
  static bool isValid(String cleanedIsbn) {
    switch (cleanedIsbn.length) {
      case 10:
        return _isValidIsbn10(cleanedIsbn);
      case 13:
        return _isValidIsbn13(cleanedIsbn);
      default:
        return false;
    }
  }

  /// Kullanıcının yazdığı ham metni doğrular ve normalize eder.
  ///
  /// Geçerliyse temizlenmiş ISBN, değilse `null` döner.
  static String? normalize(String raw) {
    final cleaned = clean(raw);
    return isValid(cleaned) ? cleaned : null;
  }

  // ISBN-10: d_i * (11 - i) toplamı mod 11 == 0. Son hane 'X' ise 10 sayılır.
  static bool _isValidIsbn10(String isbn) {
    var total = 0;
    for (var i = 0; i < 10; i++) {
      final ch = isbn[i];
      final weight = 10 - i;
      if (ch == 'X' || ch == 'x') {
        // 'X' yalnızca kontrol hanesi (son pozisyon) olabilir.
        if (i != 9) return false;
        total += 10 * weight;
        continue;
      }
      final digit = int.tryParse(ch);
      if (digit == null) return false;
      total += digit * weight;
    }
    return total % 11 == 0;
  }

  // ISBN-13: 1 ve 3 ağırlıklı çapraz toplam mod 10 == 0.
  static bool _isValidIsbn13(String isbn) {
    var total = 0;
    for (var i = 0; i < 13; i++) {
      final digit = int.tryParse(isbn[i]);
      if (digit == null) return false;
      total += digit * (i.isEven ? 1 : 3);
    }
    return total % 10 == 0;
  }
}

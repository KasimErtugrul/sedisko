/// Türkçe metin karşılaştırma/arama yardımcıları.
///
/// Dart'ın varsayılan `toLowerCase()` ve `compareTo()` metotları
/// Türkçe için iki sorun yaratır:
///
/// 1. `İ` küçültülürken "i + birleştirici nokta" (U+0307) üretir, bu da
///    aramalarda `istanbul` ile `İstanbul` eşleşmesini bozar.
/// 2. `compareTo()` Unicode kod sırasına göre çalışır; `ç`, `ğ`, `ş` harfleri
///    alfabetik sıralamadan çıkar.
library;

class TextNormalizer {
  const TextNormalizer._();

  /// `İ`.toLowerCase() çağrısının ürettiği birleştirici nokta.
  static final RegExp _combiningDot = RegExp('\u0307');

  /// Arama için tam katlama tablosu: İ/ı→i, ü→u, ö→o, ş→s, ç→c, ğ→g.
  /// Böylece kullanıcı "dunya" yazdığında "Dünya" da eşleşir.
  static const Map<String, String> _foldMap = <String, String>{
    'İ': 'i',
    'I': 'i',
    'ı': 'i',
    'Ç': 'c',
    'ç': 'c',
    'Ğ': 'g',
    'ğ': 'g',
    'Ö': 'o',
    'ö': 'o',
    'Ş': 's',
    'ş': 's',
    'Ü': 'u',
    'ü': 'u',
    'Â': 'a',
    'â': 'a',
    'Î': 'i',
    'î': 'i',
    'Û': 'u',
    'û': 'u',
  };

  /// Türkçe büyük harflerin küçük karşılıkları (I/İ özel durumu dahil).
  /// Sıralama için kullanılır: ı ve i ayrı harfler olarak kalır.
  static const Map<String, String> _lowerMap = <String, String>{
    'I': 'ı',
    'İ': 'i',
    'Ç': 'ç',
    'Ğ': 'ğ',
    'Ö': 'ö',
    'Ş': 'ş',
    'Ü': 'ü',
    'Q': 'q',
    'W': 'w',
    'X': 'x',
  };

  /// Türkçe alfabedeki harf sıralaması (q, w, x dahil değil).
  static const String _alphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

  /// Arama anahtarı üretir: hem girdi hem kitap verisi aynı anahtarla
  /// normalizasyon yapılmalı ki Türkçe İ/ı ve aksanlı harf eşleşmesi
  /// bozulmasın.
  ///
  /// Örn. `searchKey('İRMAK') == searchKey('ırmak')` → `'irmak'`,
  /// `searchKey('Dünya') == searchKey('dunya')`.
  static String searchKey(String input) {
    final sb = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      sb.write(_foldMap[ch] ?? ch.toLowerCase());
    }
    // Güvenlik: kalan birleştirici noktaları (varsa) temizle.
    return sb.toString().replaceAll(_combiningDot, '');
  }

  /// Türkçe alfabe sırasına göre karşılaştırır (collation).
  ///
  /// Alfabe dışı karakterler Unicode kod sırasına göre değerlendirilir.
  /// `compareTr('çicek', 'zeynep') < 0` çünkü `ç` alfabe sırasında `z`'den önce.
  static int compareTr(String a, String b) {
    final ka = _sortKey(a);
    final kb = _sortKey(b);
    final len = ka.length < kb.length ? ka.length : kb.length;
    for (var i = 0; i < len; i++) {
      final rankA = _rank(ka[i]);
      final rankB = _rank(kb[i]);
      if (rankA != rankB) return rankA.compareTo(rankB);
    }
    return ka.length.compareTo(kb.length);
  }

  /// Sıralama için: I→ı, İ→i dönüşümü yapılır (arama anahtarından farklı;
  /// ı ve i ayrı harflerdir ve sıralamada ayrı kalmalı).
  static String _sortKey(String input) {
    final sb = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      sb.write(_lowerMap[ch] ?? ch.toLowerCase());
    }
    return sb.toString().replaceAll(_combiningDot, '');
  }

  static int _rank(String ch) {
    final index = _alphabet.indexOf(ch);
    // Türkçe alfabede olmayan harfler sona değil, alfabe dışı olarak
    // kod sırasıyla değerlendirilir (2000 + rune) — sıralama kararlı kalır.
    return index >= 0 ? index : 1000 + ch.runes.first;
  }
}

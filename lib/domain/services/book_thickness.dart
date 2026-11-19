/// Sayfa sayısından fiziksel kalınlık tahmini.
///
/// Kullanıcı geri bildirimi (1.15.0): "40 kitap diyoruz ama çok kalın
/// kitaplar sığmıyor; 40 kalın kitap, 60 normal kitabın kapladığı yeri
/// kaplıyor." Kapasite bu yüzden artık yalnız kitap SAYISI değil, kitabın
/// kapladığı YER (birim) cinsinden de hesaplanabilir.
///
/// Ölçek: **≈ 350 sayfa = 1 birim** (orta boy ciltsiz bir kitabın
/// raflık genişliği). 0,5 birim duyarlılıkla yuvarlanır; daha ince
/// hesaplar planlamada huzursuzluk yaratır, daha kaba olan alanı boşa
/// çıkarır. Sayfa sayısı bilinmeyen kitaplar (0) 1 birim sayılır:
/// eksik bilgi kitabı cezalandırmaz.
///
/// Planlama tam sayılarla yapılır: her değer **yarım birim** olarak
/// tutulur (1 = 0,5 birim, 2 = 1 birim, 3 = 1,5 birim …). Böylece
/// 0,5'lik adımlar kayan nokta hatası olmadan, kararlı biçimde
/// karşılaştırılır.
abstract final class BookThickness {
  /// 1 birimin karşılık geldiği sayfa sayısı.
  static const double referencePages = 350;

  /// Bilinmeyen (0) sayfa sayısının kapladığı yer: 1 birim.
  static const int unknownHalfUnits = 2;

  /// En küçük yer: 0,5 birim (çok ince kitaplar için taban).
  static const int minHalfUnits = 1;

  /// Kalınlık hesabı KAPALIYKEN her kitabın kapladığı sabit yer
  /// (1 birim) — 1.13.0/1.14.0'daki kitap sayısı davranışı.
  static const int flatHalfUnits = 2;

  /// Kitabın kapladığı yer, yarım birim cinsinden.
  ///
  /// [pageCount] <= 0 → bilinmeyen → 1 birim. Değerler örnek:
  /// 40 sayfa → 0,5 · 175 → 0,5 · 300 → 1,0 · 525 → 1,5 · 700 → 2,0 ·
  /// 1050 → 3,0 (kullanıcının "40 kalın = 60 normal" gözlemiyle uyumlu:
  /// ~525 sayfalık kitaplar 1,5 birim yer kaplar).
  static int halfUnitsOf(int pageCount) {
    if (pageCount <= 0) return unknownHalfUnits;
    final half = (pageCount / referencePages * 2).round();
    return half < minHalfUnits ? minHalfUnits : half;
  }

  /// Planlamanın kullandığı maliyet: kalınlık hesabı açıksa sayfa
  /// sayısından, kapalıysa her kitaba sabit 1 birim.
  static int costHalfUnits(int pageCount, {required bool thicknessAware}) =>
      thicknessAware ? halfUnitsOf(pageCount) : flatHalfUnits;

  /// Yarım birimi okunur birime çevirir (4 → 2.0).
  static double unitsOf(int halfUnits) => halfUnits / 2;

  /// Yarım birimi Türkçe gösterimle yazar: 2 → '1', 3 → '1,5', 7 → '3,5'.
  static String formatHalf(int halfUnits) {
    final units = unitsOf(halfUnits);
    if (units == units.roundToDouble()) {
      return units.toInt().toString();
    }
    return units.toStringAsFixed(1).replaceAll('.', ',');
  }

  /// Kalınlık etiketi; kitap kartlarında ve açıklamalarda kullanılır.
  /// 0,5 → 'İnce', 1 → 'Normal', 1,5 → 'Kalın', 2 ve üzeri → 'Çok kalın'.
  static String labelOf(int halfUnits) {
    if (halfUnits <= minHalfUnits) return 'İnce';
    if (halfUnits <= 2) return 'Normal';
    if (halfUnits <= 3) return 'Kalın';
    return 'Çok kalın';
  }
}

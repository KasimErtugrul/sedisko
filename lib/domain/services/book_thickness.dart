/// Sayfa sayısından fiziksel kalınlık tahminİ — SANTİMETRE MODELİ (1.19.0).
///
/// Kullanıcı ölçümleriyle kalibre edildi: **420 sayfa ≈ 3 cm, 130 sayfa
/// ≈ 1 cm.** İki nokta arasındaki doğrusal formül:
///
///     kalınlık(mm) = (300 + 20 × sayfa) / 290
///
/// Eski "≈350 sayfa = 1 birim" yer tutusu bırakıldı; raf kapasitesi artık
/// kullanıcının cm cinsinden girdiği raf uzunluğudur ve kitaplar mm
/// cinsinden yer kaplar. Sayfa sayısı bilinmeyen kitaplar (0) normal bir
/// kitap sayılır (≈ 2,5 cm): eksik bilgi kitabı cezalandırmaz.
///
/// Planlama tam sayılarla yapılır: her değer **milimetre** olarak tutulur.
/// Raf bütçesi `lengthCm × 10` mm'dir; 1 mm'lik adım planlamada yeterlidir
/// (kullanıcı zaten cm ile düşünür) ve kayan nokta hatası olmadan
/// karşılaştırılır.
abstract final class BookThickness {
  /// Sayfa sayısı bilinmeyen kitabın kapladığı yer: 2,5 cm (normal kitap).
  static const int unknownMm = 25;

  /// En küçük yer: 1 mm (aşırı ince broşür için taban).
  static const int minMm = 1;

  /// Kitabın tahmini kalınlığı, milimetre cinsinden.
  ///
  /// [pageCount] <= 0 → bilinmeyen → 25 mm (2,5 cm). Örnekler:
  /// 130 sayfa → 10 mm (1 cm) · 350 sayfa → 25 mm (2,5 cm) ·
  /// 420 sayfa → 30 mm (3 cm) · 700 sayfa → 50 mm (5 cm).
  static int mmOf(int pageCount) {
    if (pageCount <= 0) return unknownMm;
    // round((300 + 20 × p) / 290): (2a + b) ~/ (2b) tam sayı yuvarlaması.
    final a = 300 + 20 * pageCount;
    final mm = (2 * a + 290) ~/ (2 * 290);
    return mm < minMm ? minMm : mm;
  }

  /// Milimetreyi Türkçe gösterimle santimetreye çevirir:
  /// 30 → '3 cm' · 964 → '96,4 cm' · 1250 → '125 cm'.
  static String formatMm(int mm) {
    final cm = mm / 10;
    if (cm == cm.roundToDouble()) {
      return '${cm.toInt()} cm';
    }
    return '${cm.toStringAsFixed(1).replaceAll('.', ',')} cm';
  }

  /// Kalınlık etiketi; kitap kartlarında ve açıklamalarda kullanılır.
  /// ≤1 cm → 'İnce', ≤2,5 cm → 'Normal' (≈350 sayfa), ≤3,5 cm → 'Kalın'
  /// (420 sayfa 'Kalın'), 3,5 cm üzeri → 'Çok kalın' (≈525 sayfa ve üstü).
  static String labelOf(int mm) {
    if (mm <= 10) return 'İnce';
    if (mm <= 25) return 'Normal';
    if (mm <= 35) return 'Kalın';
    return 'Çok kalın';
  }
}

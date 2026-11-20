import '../../core/utils/text_normalizer.dart';

/// Hedef düzenin isteğe bağlı kuralları.
///
/// Kullanıcı isteği (1.15.0): "raf düzenleme işleminde keşke öncelikle bana
/// favori rafımı ve favori yazarlarımı sorsa; favori rafıma favori
/// yazarlarımı görebilsem".
///
/// **1.19.0 — favoriler yalnız "Yazara göre"dedir:** kullanıcı kararıyla
/// favori raf + favori yazarlar tercihi YALNIZCA kriter "Yazara göre"
/// seçiliyken devreye girer (ShelfPlanner bunu denetler). Yayınevine göre /
/// kitap adına göre / sayfa sayısına göre düzenlemeleri kendi başlarına,
/// favorilerden bağımsız çalışır.
///
/// - [favoriteShelfId] + [favoriteAuthors] birlikte anlamlıdır: favori
///   yazarların kitapları planın EN BAŞINDA favori rafa BÜTÜN halinde
///   (yazar asla bölünmeden, 1.17.0) yerleştirilir; favori raf yalnızca
///   favori yazarların kitaplarını tutar, kalan kitaplar seçilen
///   kriterle dağıtılır. Yalnız biri seçildiyse favori planlamayı
///   etkilemez (yarım tercih, sessizce yok sayılır).
/// - Kapasite 1.19.0'dan beri cm cinsindendir: raf uzunluğu bütçe, kitabın
///   yeri kalınlıktır (BookThickness). Birim anahtarı kaldırıldı.
class OrganizeOptions {
  const OrganizeOptions({
    this.favoriteShelfId,
    this.favoriteAuthors = const [],
  });

  /// Favori rafın `shelves_v1` kimliği; yoksa ya da raf silinmişse null.
  final String? favoriteShelfId;

  /// Kullanıcının sıraladığı favori yazarlar; listedeki sıra raftaki
  /// yerleşim sırasını belirler.
  final List<String> favoriteAuthors;

  /// Favori yerleştirme tercihi kayıtlı mı? (Planlayıcı bunu yalnız
  /// "Yazara göre" kriterinde dikkate alır.)
  bool get hasFavorites =>
      favoriteShelfId != null &&
      favoriteShelfId!.isNotEmpty &&
      favoriteAuthors.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is OrganizeOptions &&
      other.favoriteShelfId == favoriteShelfId &&
      _sameAuthors(other.favoriteAuthors, favoriteAuthors);

  @override
  int get hashCode => Object.hash(
        favoriteShelfId,
        Object.hashAll(favoriteAuthors.map(TextNormalizer.searchKey)),
      );

  static bool _sameAuthors(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (TextNormalizer.searchKey(a[i]) != TextNormalizer.searchKey(b[i])) {
        return false;
      }
    }
    return true;
  }
}

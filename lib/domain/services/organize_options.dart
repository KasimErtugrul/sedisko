import '../../core/utils/text_normalizer.dart';

/// Hedef düzenin isteğe bağlı kuralları (1.15.0).
///
/// Kullanıcı isteği: "raf düzenleme işleminde keşke öncelikle bana favori
/// rafımı ve favori yazarlarımı sorsa; favori rafıma favori yazarlarımı
/// görebilsem" ve "sayfa sayısı da önemliymiş; çok kalın kitaplar
/// sığmıyor".
///
/// - [favoriteShelfId] + [favoriteAuthors] birlikte anlamlıdır: favori
///   yazarların kitapları planın EN BAŞINDA favori rafa yerleştirilir,
///   kalan kitaplar seçilen kriterle dağıtılır. Yalnız biri seçildiyse
///   favori planlamayı etkilemez (yarım tercih, sessizce yok sayılır).
/// - [thicknessAware] açıksa kapasite kitap sayısı değil YER (birim)
///   cinsinden hesaplanır: her rafın kitap kapasitesi birim bütçesine
///   dönüşür, kitabın kapladığı yer sayfa sayısından gelir.
class OrganizeOptions {
  const OrganizeOptions({
    this.favoriteShelfId,
    this.favoriteAuthors = const [],
    this.thicknessAware = false,
  });

  /// Favori rafın `shelves_v1` kimliği; yoksa ya da raf silinmişse null.
  final String? favoriteShelfId;

  /// Kullanıcının sıraladığı favori yazarlar; listedeki sıra raftaki
  /// yerleşim sırasını belirler.
  final List<String> favoriteAuthors;

  /// Kapasite birim (yer) cinsinden hesaplansın mı?
  final bool thicknessAware;

  /// Favori yerleştirme devrede mi?
  bool get hasFavorites =>
      favoriteShelfId != null &&
      favoriteShelfId!.isNotEmpty &&
      favoriteAuthors.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is OrganizeOptions &&
      other.favoriteShelfId == favoriteShelfId &&
      _sameAuthors(other.favoriteAuthors, favoriteAuthors) &&
      other.thicknessAware == thicknessAware;

  @override
  int get hashCode => Object.hash(
        favoriteShelfId,
        Object.hashAll(favoriteAuthors.map(TextNormalizer.searchKey)),
        thicknessAware,
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

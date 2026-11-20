/// Raf düzeni asistanının kitapları dağıtırken kullandığı kriter.
///
/// "Grup" kriterleri (yazar / yayınevi) aynı değerli kitapları TEK rafta
/// birleştirmeye çalışır; grup sırası kitap sayısı çoktan azadır (eşitlikte
/// Türkçe alfabe). "Akış" kriterleri (kitap adı / sayfa sayısı) kitapları
/// tek bir sıraya dizer ve raf dolunca sıradaki rafa geçer (gerçek
/// kütüphane akışı).
///
/// **1.19.0:** favori raf ve favori yazarlar YALNIZCA "Yazara göre"
/// kriterinde devreye girer; öteki üç kriter kendi başlarına, favorilerden
/// bağımsız çalışır.
enum OrganizeCriterion {
  author(
    'Yazara göre',
    'Aynı yazarın kitapları tek rafta birleşir; yazarlar kitap sayısı '
        'çoktan aza dizilir. Yazar ASLA ikiye bölünmez: sığmayan yazar '
        'bütün halinde başka bir rafa ya da Karışık kitaplar rafına '
        'gider. Favori raf ve favori yazarlar yalnız bu seçimde çalışır.',
  ),
  publisher(
    'Yayınevine göre',
    'Aynı yayınevinin kitapları tek rafta birleşir; yayınevleri kitap '
        'sayısı çoktan aza dizilir. Tek rafa sığmayan yayınevi, en geniş '
        'rafa sığan kadarı konup artığı Karışık kitaplar rafına giderek '
        'yerine yerleştirilir. Favoriler bu seçimde devrede değildir.',
  ),
  title(
    'Kitap adına göre',
    'Kitaplar A→Z dizilir; raf dolunca sıradaki rafa geçer. '
        'Favoriler bu seçimde devrede değildir.',
  ),
  pageCount(
    'Sayfa sayısına göre',
    'Kitaplar inceden kalına dizilir; raf dolunca sıradaki rafa geçer. '
        'Favoriler bu seçimde devrede değildir.',
  ),
  ;

  const OrganizeCriterion(this.label, this.description);

  final String label;
  final String description;

  /// true: kitaplar gruba ayrılır (aynı grup tek rafta); false: akış
  /// modu (sıralı dizer, kapasiteye göre raflara böler).
  bool get isGrouped => this == author || this == publisher;
}

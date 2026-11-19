/// Raf düzeni asistanının kitapları dağıtırken kullandığı kriter.
///
/// "Grup" kriterleri (yazar / yayınevi) aynı değerli kitapları TEK rafta
/// birleştirmeye çalışır; grup sırası kitap sayısı çoktan azadır (eşitlikte
/// Türkçe alfabe). "Akış" kriterleri (kitap adı / sayfa sayısı) kitapları
/// tek bir sıraya dizer ve raf dolunca sıradaki rafa geçer (gerçek
/// kütüphane akışı).
enum OrganizeCriterion {
  author(
    'Yazara göre',
    'Aynı yazarın kitapları tek rafta birleşir; yazarlar kitap sayısı '
        'çoktan aza dizilir.',
  ),
  publisher(
    'Yayınevine göre',
    'Aynı yayınevinin kitapları tek rafta birleşir; yayınevleri kitap '
        'sayısı çoktan aza dizilir.',
  ),
  title(
    'Kitap adına göre',
    'Kitaplar A→Z dizilir; raf dolunca sıradaki rafa geçilir.',
  ),
  pageCount(
    'Sayfa sayısına göre',
    'Kitaplar inceden kalına dizilir; raf dolunca sıradaki rafa geçilir.',
  );

  const OrganizeCriterion(this.label, this.description);

  final String label;
  final String description;

  /// true: kitaplar gruba ayrılır (aynı grup tek rafta); false: akış
  /// modu (sıralı dizer, kapasiteye göre raflara böler).
  bool get isGrouped => this == author || this == publisher;
}

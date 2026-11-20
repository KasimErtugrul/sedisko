import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/domain/services/book_thickness.dart';

/// Sayfa sayısından kalınlık tahminİ — cm modeli (1.19.0).
///
/// Kullanıcı ölçümleri: **420 sayfa ≈ 3 cm, 130 sayfa ≈ 1 cm.** Doğrusal
/// formül: mm ≈ (300 + 20 × sayfa) / 290; bilinmeyen sayfa = 2,5 cm
/// (normal kitap); planlama milimetre tam sayılarıyla yapılır.
void main() {
  group('mmOf: sayfa sayısı → milimetre', () {
    test('kullanıcının iki ölçümü birebir tutar', () {
      expect(BookThickness.mmOf(420), 30); // 3,0 cm
      expect(BookThickness.mmOf(130), 10); // 1,0 cm
    });

    test('bilinmeyen ve sıfır sayfa 2,5 cm sayılır (ceza yok)', () {
      expect(BookThickness.mmOf(0), BookThickness.unknownMm);
      expect(BookThickness.mmOf(-5), BookThickness.unknownMm);
      expect(BookThickness.unknownMm, 25); // 2,5 cm
    });

    test('orta kalınlıklar formülü izler', () {
      expect(BookThickness.mmOf(40), 4); // 0,4 cm — broşür
      expect(BookThickness.mmOf(175), 13); // 1,3 cm
      expect(BookThickness.mmOf(300), 22); // 2,2 cm
      expect(BookThickness.mmOf(437), 31); // 3,1 cm
      expect(BookThickness.mmOf(525), 37); // 3,7 cm
      expect(BookThickness.mmOf(700), 49); // 4,9 cm
      expect(BookThickness.mmOf(1050), 73); // 7,3 cm
    });

    test('eski referans kitap ≈ 2,5 cm kalır (≈350 sayfa)', () {
      expect(BookThickness.mmOf(350), 25);
    });

    test('artan sayfa kalınlığı hiç azaltmaz (monoton)', () {
      var previous = 0;
      for (final pages in [10, 50, 100, 130, 200, 300, 350, 420, 500, 700,
        1050]) {
        final mm = BookThickness.mmOf(pages);
        expect(mm, greaterThanOrEqualTo(previous),
            reason: '$pages sayfa $previous mm\'den küçük olamaz');
        previous = mm;
      }
    });

    test('taban 1 mm\'dir', () {
      expect(BookThickness.mmOf(1), 1);
      expect(BookThickness.minMm, 1);
    });
  });

  group('gösterim', () {
    test('formatMm tam santimetreyi sade yazar', () {
      expect(BookThickness.formatMm(30), '3 cm');
      expect(BookThickness.formatMm(10), '1 cm');
      expect(BookThickness.formatMm(250), '25 cm');
      expect(BookThickness.formatMm(1250), '125 cm');
      expect(BookThickness.formatMm(1000), '100 cm');
    });

    test('formatMm kesirli santimetrede Türkçe virgül kullanır', () {
      expect(BookThickness.formatMm(964), '96,4 cm');
      expect(BookThickness.formatMm(25), '2,5 cm');
      expect(BookThickness.formatMm(5), '0,5 cm');
      expect(BookThickness.formatMm(22), '2,2 cm');
    });

    test('labelOf kalınlık sınıfını adlandırır', () {
      expect(BookThickness.labelOf(4), 'İnce');
      expect(BookThickness.labelOf(10), 'İnce'); // 1 cm
      expect(BookThickness.labelOf(13), 'Normal');
      expect(BookThickness.labelOf(25), 'Normal'); // ≈350 sayfa
      expect(BookThickness.labelOf(30), 'Kalın'); // 420 sayfa
      expect(BookThickness.labelOf(35), 'Kalın');
      expect(BookThickness.labelOf(37), 'Çok kalın'); // ≈525 sayfa
      expect(BookThickness.labelOf(49), 'Çok kalın');
    });
  });
}

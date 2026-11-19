import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/domain/services/book_thickness.dart';

/// Sayfa sayısından kalınlık (yer) tahmini.
///
/// Kullanıcı gözlemi (1.15.0): "40 kitap diyoruz ama çok kalın kitaplarla
/// sığmıyor; 60 kitabın kapladığı yeri kaplıyor." Ölçek: ≈350 sayfa =
/// 1 birim; 0,5 birim duyarlılık; bilinmeyen sayfa = 1 birim.
void main() {
  group('halfUnitsOf: sayfa sayısı → yarım birim', () {
    test('bilinmeyen ve sıfır sayfa 1 birimdir (ceza yok)', () {
      expect(BookThickness.halfUnitsOf(0), BookThickness.unknownHalfUnits);
      expect(BookThickness.halfUnitsOf(-5), BookThickness.unknownHalfUnits);
      expect(BookThickness.unknownHalfUnits, 2); // 2 yarım = 1 birim
    });

    test('ince kitaplar 0,5 birime yuvarlanır (taban 0,5)', () {
      expect(BookThickness.halfUnitsOf(40), 1); // 0,5 birim
      expect(BookThickness.halfUnitsOf(175), 1); // 0,5 birim
    });

    test('referans çevresinde normal 1 birim', () {
      expect(BookThickness.halfUnitsOf(300), 2); // 1,0 birim
      expect(BookThickness.halfUnitsOf(350), 2); // 1,0 birim
      expect(BookThickness.halfUnitsOf(437), 2); // 1,25 → 1,0'a yuvarlanır
    });

    test('kalın kitaplar 1,5 ve 2 birim yer kaplar', () {
      expect(BookThickness.halfUnitsOf(438), 3); // 1,25+ → 1,5
      expect(BookThickness.halfUnitsOf(525), 3); // 1,5 birim
      expect(BookThickness.halfUnitsOf(612), 3); // 1,75'e ulaşıp yuvarlanmadı
      expect(BookThickness.halfUnitsOf(620), 4); // 1,75+ → 2,0
      expect(BookThickness.halfUnitsOf(700), 4); // 2,0 birim
    });

    test('çok kalın kitaplar 2 birimi aşar', () {
      expect(BookThickness.halfUnitsOf(875), 5); // 2,5 birim
      expect(BookThickness.halfUnitsOf(1050), 6); // 3,0 birim
    });

    test('kullanıcı gözlemi: ~525 sayfalık kitaplar 1,5 birimdir', () {
      // 40 kalin kitap = 60 normal kitabin yeri: 40 x 1,5 = 60 birim.
      final thickUnits = BookThickness.unitsOf(BookThickness.halfUnitsOf(525));
      expect(thickUnits, 1.5);
    });
  });

  group('costHalfUnits: planlama maliyeti', () {
    test('kalınlık kapalıyken her kitap 1 birimdir', () {
      expect(
        BookThickness.costHalfUnits(1050, thicknessAware: false),
        BookThickness.flatHalfUnits,
      );
      expect(BookThickness.costHalfUnits(0, thicknessAware: false), 2);
    });

    test('kalınlık açıkken maliyet sayfa sayısından gelir', () {
      expect(BookThickness.costHalfUnits(525, thicknessAware: true), 3);
      expect(BookThickness.costHalfUnits(0, thicknessAware: true), 2);
    });
  });

  group('gösterim', () {
    test('formatHalf Türkçe ondalık virgülüyle yazar', () {
      expect(BookThickness.formatHalf(2), '1');
      expect(BookThickness.formatHalf(3), '1,5');
      expect(BookThickness.formatHalf(4), '2');
      expect(BookThickness.formatHalf(7), '3,5');
      expect(BookThickness.formatHalf(1), '0,5');
    });

    test('labelOf kalınlık sınıfını adlandırır', () {
      expect(BookThickness.labelOf(1), 'İnce');
      expect(BookThickness.labelOf(2), 'Normal');
      expect(BookThickness.labelOf(3), 'Kalın');
      expect(BookThickness.labelOf(4), 'Çok kalın');
      expect(BookThickness.labelOf(6), 'Çok kalın');
    });
  });
}

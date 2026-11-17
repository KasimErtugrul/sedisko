import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/core/utils/text_normalizer.dart';

void main() {
  group('TextNormalizer.searchKey', () {
    test('Türkçe İ ile yazılan metin, i ile yazılanla eşleşir', () {
      // Bu test, orijinal koddaki `İstanbul.toLowerCase()` problemini
      // (i + birleştirici nokta) sabitler.
      expect(
        TextNormalizer.searchKey('İstanbul'),
        TextNormalizer.searchKey('istanbul'),
      );
      expect(
        TextNormalizer.searchKey('İSTANBUL'),
        TextNormalizer.searchKey('istanbul'),
      );
    });

    test('ı harfi i olarak normalize edilir (arama için)', () {
      expect(
        TextNormalizer.searchKey('IRMAK'),
        TextNormalizer.searchKey('irmak'),
      );
      expect(TextNormalizer.searchKey('Yılmaz'), 'yilmaz');
    });

    test('birleştirici nokta kalıntısı bırakmaz', () {
      expect(TextNormalizer.searchKey('İZMİR').contains('\u0307'), isFalse);
    });

    test('boş ve noktalı girdiler değişmeden küçülür', () {
      expect(TextNormalizer.searchKey(''), '');
      expect(TextNormalizer.searchKey('  Kayıp Dünya  '), '  kayip dunya  ');
    });
  });

  group('TextNormalizer.compareTr', () {
    test('ç harfi z harfinden önce gelir', () {
      expect(TextNormalizer.compareTr('çicek', 'zeynep'), lessThan(0));
      expect(TextNormalizer.compareTr('zeynep', 'çicek'), greaterThan(0));
    });

    test('ş ve ğ harfleri doğru sırada', () {
      expect(TextNormalizer.compareTr('şeker', 'tuz'), lessThan(0));
      expect(TextNormalizer.compareTr('dağ', 'deniz'), lessThan(0));
    });

    test('ı harfi i harfinden önce gelir (Türkçe alfabe)', () {
      expect(TextNormalizer.compareTr('ıspanak', 'iptables'), lessThan(0));
    });

    test('büyük/küçük harf duyarsızdır', () {
      expect(TextNormalizer.compareTr('Ahmet', 'ahmet'), 0);
      expect(TextNormalizer.compareTr('ÇAĞ', 'çağ'), 0);
    });

    test('aynı metin 0 döner', () {
      expect(TextNormalizer.compareTr('kitap', 'kitap'), 0);
    });

    test('önek kısa olanı önce koyar', () {
      expect(TextNormalizer.compareTr('kitap', 'kitaplık'), lessThan(0));
    });
  });
}

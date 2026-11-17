import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/core/utils/isbn_validator.dart';

void main() {
  group('IsbnValidator.clean', () {
    test('tire, boşluk ve diğer ayırıcıları temizler', () {
      expect(IsbnValidator.clean('978-0-13-235088-4'), '9780132350884');
      expect(IsbnValidator.clean('978 0 13 235088 4'), '9780132350884');
      expect(IsbnValidator.clean('  9780132350884 '), '9780132350884');
    });

    test('ISBN-10 sonundaki X harfini korur', () {
      expect(IsbnValidator.clean('0-8044-2957-X'), '080442957X');
      expect(IsbnValidator.clean('0-8044-2957-x'), '080442957x');
    });

    test('harf ve diğer karakterleri siler', () {
      expect(IsbnValidator.clean('978abc0132350884'), '9780132350884');
    });
  });

  group('IsbnValidator.isValid', () {
    test('geçerli ISBN-13 numaralarını onaylar', () {
      expect(IsbnValidator.isValid('9780132350884'), isTrue); // Clean Code
      expect(IsbnValidator.isValid('9783161484100'), isTrue); // Wikipedia örneği
    });

    test('geçersiz ISBN-13 kontrol hanesini reddeder', () {
      expect(IsbnValidator.isValid('9780132350885'), isFalse);
      expect(IsbnValidator.isValid('9783161484101'), isFalse);
    });

    test('geçerli ISBN-10 numaralarını onaylar', () {
      expect(IsbnValidator.isValid('0306406152'), isTrue); // Wikipedia örneği
    });

    test('X ile biten geçerli ISBN-10 numarasını onaylar', () {
      expect(IsbnValidator.isValid('080442957X'), isTrue);
      expect(IsbnValidator.isValid('080442957x'), isTrue);
    });

    test('yanlış uzunluktaki numaraları reddeder', () {
      expect(IsbnValidator.isValid('97801323508'), isFalse); // 11 hane
      expect(IsbnValidator.isValid('97801323508841'), isFalse); // 14 hane
      expect(IsbnValidator.isValid(''), isFalse);
    });

    test('ISBN-10 ortasında X bulursa reddeder', () {
      expect(IsbnValidator.isValid('03064X6152'), isFalse);
    });
  });

  group('IsbnValidator.normalize', () {
    test('geçerli girişte temizlenmiş ISBN döner', () {
      expect(IsbnValidator.normalize('978-3-16-148410-0'), '9783161484100');
    });

    test('geçersiz girişte null döner', () {
      expect(IsbnValidator.normalize('12345'), isNull);
      expect(IsbnValidator.normalize('9783161484109'), isNull);
      expect(IsbnValidator.normalize(''), isNull);
    });
  });
}

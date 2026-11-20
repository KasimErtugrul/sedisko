import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/backup_model.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';

BackupEnvelope sampleEnvelope() => BackupEnvelope(
      exportedAt: DateTime(2026, 11, 19, 14, 30),
      appVersion: '1.14.0',
      books: [
        BookModel(
          id: 'b1',
          title: 'Dune',
          isbn: '9780441172719',
          authors: ['Frank Herbert'],
          addedAt: DateTime(2026, 1, 1),
        ),
      ],
      shelves: [
        ShelfModel(
          id: 's1',
          name: 'Roman',
          lengthCm: 125,
          location: 'Alt kat',
          order: 0,
        ),
      ],
    );

Map<String, dynamic> decodedSample() =>
    Map<String, dynamic>.from(jsonDecode(sampleEnvelope().encode()) as Map);

void main() {
  group('kodlama ve geri çözme döngüsü', () {
    test('zarf kodlanır ve aynı veriyle geri çözülür', () {
      final result = BackupEnvelope.parse(sampleEnvelope().encode());

      expect(result.isSuccess, isTrue);
      final parsed = result.envelope!;
      expect(parsed.books.length, 1);
      expect(parsed.books.first.id, 'b1');
      expect(parsed.books.first.title, 'Dune');
      expect(parsed.books.first.isbn, '9780441172719');
      expect(parsed.books.first.authors, ['Frank Herbert']);
      expect(parsed.shelves.length, 1);
      expect(parsed.shelves.first.name, 'Roman');
      expect(parsed.shelves.first.lengthCm, 125);
      expect(parsed.shelves.first.location, 'Alt kat');
      expect(parsed.exportedAt, DateTime(2026, 11, 19, 14, 30));
      expect(parsed.appVersion, '1.14.0');
    });

    test('boş kitaplık zarfı da kodlanıp geri çözülür', () {
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [],
        shelves: [],
      );
      final result = BackupEnvelope.parse(envelope.encode());
      expect(result.isSuccess, isTrue);
      expect(result.envelope!.books, isEmpty);
      expect(result.envelope!.shelves, isEmpty);
    });

    test('JSON dosyasında etiket, sürüm ve sayaçlar yer alır', () {
      final map = decodedSample();
      expect(map['format'], BackupEnvelope.formatTag);
      expect(map['formatVersion'], BackupEnvelope.formatVersion);
      expect((map['counts'] as Map)['books'], 1);
      expect((map['counts'] as Map)['shelves'], 1);
    });
  });

  group('geçersiz dosyalar reddedilir', () {
    test('bozuk JSON reddedilir', () {
      final result = BackupEnvelope.parse('{bozuk json');
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('geçerli bir JSON'));
    });

    test('kök bir liste ise reddedilir', () {
      final result = BackupEnvelope.parse('[]');
      expect(result.isSuccess, isFalse);
    });

    test('format etiketi farklıysa reddedilir', () {
      final map = decodedSample();
      map['format'] = 'baskayedek';
      final result = BackupEnvelope.parse(jsonEncode(map));
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('Kitaplığım yedeği değil'));
    });

    test('daha yeni formatVersion reddedilir ve güncelleme önerilir', () {
      final map = decodedSample();
      map['formatVersion'] = 99;
      final result = BackupEnvelope.parse(jsonEncode(map));
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('güncelleyin'));
    });

    test('formatVersion eksikse reddedilir', () {
      final map = decodedSample()..remove('formatVersion');
      final result = BackupEnvelope.parse(jsonEncode(map));
      expect(result.isSuccess, isFalse);
    });

    test('books bir liste değilse reddedilir', () {
      final map = decodedSample();
      map['books'] = 'bozuk';
      final result = BackupEnvelope.parse(jsonEncode(map));
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('kitap listesi bozuk'));
    });

    test('shelves bir liste değilse reddedilir', () {
      final map = decodedSample();
      map['shelves'] = 3;
      final result = BackupEnvelope.parse(jsonEncode(map));
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('raf listesi bozuk'));
    });

    test('bozuk kitap kaydı konum bilgisiyle reddedilir', () {
      final map = decodedSample();
      map['books'] = [
        Map<String, dynamic>.from((map['books'] as List).first),
        <String, dynamic>{'title': 'idsiz kitap'},
      ];
      final result = BackupEnvelope.parse(jsonEncode(map));
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('2. kitap kaydı bozuk'));
    });

    test('bozuk raf kaydı konum bilgisiyle reddedilir', () {
      final map = decodedSample();
      map['shelves'] = [<String, dynamic>{'name': 'idsiz raf'}];
      final result = BackupEnvelope.parse(jsonEncode(map));
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('1. raf kaydı bozuk'));
    });

    test('exportedAt eksikse dosya kabul edilir ve bugüne düşer', () {
      final map = decodedSample()..remove('exportedAt');
      final result = BackupEnvelope.parse(jsonEncode(map));
      expect(result.isSuccess, isTrue);
      expect(result.envelope!.exportedAt, isNotNull);
    });
  });
}

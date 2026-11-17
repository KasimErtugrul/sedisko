import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/reading_log_entry.dart';

void main() {
  group('ReadingLogEntry', () {
    test('toJson/fromJson turunu kayıpsız tamamlar', () {
      final entry = ReadingLogEntry(
        at: DateTime(2026, 3, 14, 21, 30),
        page: 42,
      );

      final restored = ReadingLogEntry.fromJson(entry.toJson());

      expect(restored, entry);
      expect(restored.page, 42);
    });

    test('tryFromJson bozuk kayıtlarda null döner', () {
      expect(ReadingLogEntry.tryFromJson(const {}), isNull);
      expect(
        ReadingLogEntry.tryFromJson(const {'at': 'tarih-degil', 'page': 3}),
        isNull,
      );
      expect(
        ReadingLogEntry.tryFromJson(
          const {'at': '2026-03-14T21:30:00.000', 'page': 'sayfa-degil'},
        ),
        isNull,
      );
      expect(
        ReadingLogEntry.tryFromJson(
          const {'at': '2026-03-14T21:30:00.000', 'page': -3},
        ),
        isNull,
      );
    });

    test('fromJson geçersiz kayıtta FormatException fırlatır', () {
      expect(() => ReadingLogEntry.fromJson(const {}), throwsFormatException);
    });

    test('BookModel JSON turu okuma günlüğünü korur', () {
      final book = BookModel(
        id: 'b1',
        title: 'Test Kitabı',
        addedAt: DateTime(2026, 1, 1),
        pageCount: 300,
        status: ReadingStatus.reading,
        currentPage: 120,
        readingLog: [
          ReadingLogEntry(at: DateTime(2026, 3, 1), page: 0),
          ReadingLogEntry(at: DateTime(2026, 3, 5), page: 120),
        ],
      );

      final restored = BookModel.tryFromJson(book.toJson());

      expect(restored, isNotNull);
      expect(restored!.readingLog, hasLength(2));
      expect(restored.readingLog.first.page, 0);
      expect(restored.readingLog.last.page, 120);
    });

    test('Günlük alanı olmayan eski veri boş günlükle ayrıştırılır', () {
      final restored = BookModel.tryFromJson(const {
        'id': 'b2',
        'title': 'Eski kayıt',
        'currentPage': 33,
        'addedAt': '2025-12-01T10:00:00.000',
      });

      expect(restored, isNotNull);
      expect(restored!.readingLog, isEmpty);
    });

    test('Bozuk tek günlük kaydı tüm günlüğü düşürmez', () {
      final restored = BookModel.tryFromJson(const {
        'id': 'b3',
        'title': 'Kısmen bozuk',
        'addedAt': '2025-12-01T10:00:00.000',
        'readingLog': [
          {'at': '2026-03-01T10:00:00.000', 'page': 0},
          {'at': 'bozuk-tarih', 'page': 40},
          {'at': '2026-03-05T10:00:00.000', 'page': 80},
        ],
      });

      expect(restored, isNotNull);
      expect(restored!.readingLog, hasLength(2));
      expect(restored.readingLog.last.page, 80);
    });
  });
}

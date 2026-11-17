import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/reading_log_entry.dart';
import 'package:kitaplik/domain/services/reading_stats.dart';

/// Akşam saatlerinde rapor edilmiş kayıtlar gibi davranır.
ReadingLogEntry entry(int day, int hour, int page) => ReadingLogEntry(
      at: DateTime(2026, 3, day, hour),
      page: page,
    );

void main() {
  group('ReadingStats.calculate', () {
    test('Boş günlük empty döner', () {
      final stats = ReadingStats.calculate(const []);

      expect(stats.totalPagesRead, 0);
      expect(stats.readingDays, 0);
      expect(stats.avgPerDay, 0);
      expect(stats.last7Days, 0);
      expect(stats.bestDayPages, 0);
      expect(stats.daily, isEmpty);
      expect(stats.events, isEmpty);
    });

    test('Tek kayıt referans noktasıdır, sayfa saymaz', () {
      final stats = ReadingStats.calculate([entry(1, 9, 0)]);

      expect(stats.totalPagesRead, 0);
      expect(stats.daily, isEmpty);
      expect(stats.bestDayPages, 0);
    });

    test('Aynı güne ait kayıtlar o güne toplanır', () {
      final stats = ReadingStats.calculate([
        entry(3, 9, 0),
        entry(3, 22, 40),
      ]);

      expect(stats.totalPagesRead, 40);
      expect(stats.readingDays, 1);
      expect(stats.daily.single.pages, 40);
      expect(stats.daily.single.day, DateTime(2026, 3, 3));
      expect(stats.avgPerDay, 40);
    });

    test('Farklı günler ayrı ayrı sayılır', () {
      final stats = ReadingStats.calculate([
        entry(1, 9, 0),
        entry(2, 21, 30),
        entry(4, 22, 80),
      ]);

      expect(stats.totalPagesRead, 80);
      expect(stats.readingDays, 2);
      expect(stats.daily[0].pages, 30);
      expect(stats.daily[1].pages, 50);
      expect(stats.bestDayPages, 50);
      // 1-4 Mart arası 4 takvim günü: 80 / 4 = 20.
      expect(stats.avgPerDay, 20);
    });

    test('Sayfa geri gidişi negatif üretmez', () {
      // 50 → 40 elle düzeltmesi o aralığı 0 sayar.
      final stats = ReadingStats.calculate([
        entry(1, 9, 0),
        entry(2, 21, 50),
        entry(3, 20, 40),
        entry(4, 21, 60),
      ]);

      expect(stats.totalPagesRead, 70);
      expect(stats.readingDays, 2);
    });

    test('Yeniden okuma sıfırlamasından sonra yeni tur sayılır', () {
      final stats = ReadingStats.calculate([
        entry(1, 9, 0),
        entry(2, 21, 100),
        entry(5, 9, 0), // "Yeniden oku": konum sıfırlandı
        entry(7, 21, 50),
      ]);

      expect(stats.totalPagesRead, 150);
      expect(stats.readingDays, 2);
    });

    test('last7Days yalnızca son 7 günü sayar', () {
      final stats = ReadingStats.calculate(
        [
          entry(1, 9, 0),
          entry(2, 21, 30), // pencere dışı (bugün: 10 Mart)
          entry(8, 9, 0),
          entry(9, 21, 25), // pencere içi
        ],
        now: DateTime(2026, 3, 10, 12),
      );

      expect(stats.totalPagesRead, 55);
      expect(stats.last7Days, 25);
    });

    test('Kayıtlar tarih sırasına sokulur', () {
      final stats = ReadingStats.calculate([
        entry(2, 21, 50),
        entry(1, 9, 0),
      ]);

      expect(stats.totalPagesRead, 50);
      expect(stats.events.first.page, 0);
      expect(stats.events.last.page, 50);
    });

    test('eventDeltas olaylarla hizalıdır', () {
      final stats = ReadingStats.calculate([
        entry(1, 9, 0),
        entry(2, 21, 30),
        entry(3, 20, 30), // sayfa değişmedi
        entry(4, 21, 55),
      ]);

      expect(stats.eventDeltas, [0, 30, 0, 25]);
    });

    test('avgPerDay takvim aralığını kullanır', () {
      final stats = ReadingStats.calculate([
        entry(1, 9, 0),
        entry(6, 21, 100),
      ]);

      // 1-6 Mart = 6 gün: 100 / 6 ≈ 16.7
      expect(stats.avgPerDay, closeTo(16.7, 0.1));
    });

    test('Gece yarısını aşan okuma rapor gününe yazılır', () {
      final stats = ReadingStats.calculate([
        entry(1, 23, 0),
        entry(2, 1, 30),
      ]);

      expect(stats.daily.single.day, DateTime(2026, 3, 2));
    });
  });

  group('DailyReading', () {
    test('eşitlik alanlara dayanır', () {
      final day1 = DateTime(2026, 3, 1);
      final a = DailyReading(day: day1, pages: 10);
      final b = DailyReading(day: day1, pages: 10);
      final c = DailyReading(day: DateTime(2026, 3, 2), pages: 10);

      expect(a, b);
      expect(a == c, isFalse);
    });
  });
}

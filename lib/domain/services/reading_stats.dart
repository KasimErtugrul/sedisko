import 'package:equatable/equatable.dart';

import '../../data/models/reading_log_entry.dart';

/// Bir gün içinde okunan sayfa sayısı.
class DailyReading extends Equatable {
  const DailyReading({required this.day, required this.pages});

  /// Yalnızca takvim günü (saat/saniye sıfırlanmış).
  final DateTime day;
  final int pages;

  @override
  List<Object?> get props => [day, pages];
}

/// Bir kitabın okuma günlüğünden türetilen istatistikler.
///
/// Hesaplama saf fonksiyonla yapılır ([ReadingStats.calculate]); widget ve
/// testler bağımlılık olmadan aynı sonucu üretir.
class ReadingStats extends Equatable {
  const ReadingStats({
    required this.totalPagesRead,
    required this.readingDays,
    required this.avgPerDay,
    required this.last7Days,
    required this.bestDayPages,
    required this.daily,
    required this.events,
    required this.eventDeltas,
  });

  /// Takip başlangıcından beri okunan toplam sayfa.
  final int totalPagesRead;

  /// En az bir sayfa okunmuş takvim günü sayısı.
  final int readingDays;

  /// Takvim aralığına (ilk kayıttan son kayda kadar geçen gün) göre
  /// günlük ortalama.
  final double avgPerDay;

  /// Bugün ve önceki 6 günde okunan toplam sayfa.
  final int last7Days;

  /// Tek günde okunan en yüksek sayfa sayısı.
  final int bestDayPages;

  /// Gün gün okunan sayfalar (artan sırada).
  final List<DailyReading> daily;

  /// Zamana göre sıralanmış günlük kayıtları.
  final List<ReadingLogEntry> events;

  /// [events] ile hizalı: her kayıtta o olayla raporlanan ilerleme
  /// (bir önceki kayıttaki sayfa farkı; ilk kayıt 0, geriye gidiş 0).
  final List<int> eventDeltas;

  static const ReadingStats empty = ReadingStats(
    totalPagesRead: 0,
    readingDays: 0,
    avgPerDay: 0,
    last7Days: 0,
    bestDayPages: 0,
    daily: [],
    events: [],
    eventDeltas: [],
  );

  /// [rawLog] kayıtlarını zamana göre sıralar, ardışık kayıtlar arasındaki
  /// sayfa farkından günlük okuma türetir.
  ///
  /// Kurallar:
  /// - İlk kayıt referans noktasıdır (o konuma kadar ne okunduğu
  ///   bilinmediğinden sayılmaz).
  /// - Sayfa geri gidişi (elle düzeltme, yeniden okuma sıfırlaması)
  ///   negatif üretmez; o aralık 0 sayılır.
  /// - Gün ataması, yeni konumun rapor edildiği günün takvim günüdür.
  static ReadingStats calculate(
    List<ReadingLogEntry> rawLog, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final events = [...rawLog]..sort((a, b) => a.at.compareTo(b.at));
    if (events.isEmpty) return empty;

    final deltas = List<int>.filled(events.length, 0);
    final dailyMap = <DateTime, int>{};
    var total = 0;

    for (var i = 1; i < events.length; i++) {
      final delta = events[i].page - events[i - 1].page;
      if (delta <= 0) continue;
      deltas[i] = delta;
      final day = DateTime(
        events[i].at.year,
        events[i].at.month,
        events[i].at.day,
      );
      dailyMap[day] = (dailyMap[day] ?? 0) + delta;
      total += delta;
    }

    final daily = dailyMap.entries
        .map((e) => DailyReading(day: e.key, pages: e.value))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    final readingDays = daily.length;
    final spanDays = _calendarDays(events.first.at, events.last.at);
    final avg = total == 0 ? 0.0 : total / spanDays;

    final today = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final windowStart = today.subtract(const Duration(days: 6));
    final last7 = daily
        .where((d) => !d.day.isBefore(windowStart) && !d.day.isAfter(today))
        .fold(0, (sum, d) => sum + d.pages);

    final best =
        daily.isEmpty ? 0 : daily.map((d) => d.pages).reduce(_maxOf);

    return ReadingStats(
      totalPagesRead: total,
      readingDays: readingDays,
      avgPerDay: avg,
      last7Days: last7,
      bestDayPages: best,
      daily: daily,
      events: events,
      eventDeltas: deltas,
    );
  }

  /// İki tarih arasındaki takvim günü sayısı (dahil, en az 1).
  static int _calendarDays(DateTime a, DateTime b) {
    final start = DateTime(a.year, a.month, a.day);
    final end = DateTime(b.year, b.month, b.day);
    final diff = end.difference(start).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  static int _maxOf(int a, int b) => a > b ? a : b;

  @override
  List<Object?> get props => [
        totalPagesRead,
        readingDays,
        avgPerDay,
        last7Days,
        bestDayPages,
        daily,
        events,
        eventDeltas,
      ];
}

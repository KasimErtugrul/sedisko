import 'package:flutter/material.dart';

import '../../data/models/book_model.dart';
import '../../domain/services/reading_stats.dart';

/// Kitap detay sayfasının altında gösterilen okuma istatistikleri kartı.
///
/// İçerik kitabın okuma günlüğünden türetilir: toplam okunan sayfa,
/// günlük ortalama, son 7 gün, en verimli gün, son 14 günün bar grafiği
/// ve son günlük kayıtları.
class ReadingStatsPanel extends StatelessWidget {
  const ReadingStatsPanel({super.key, required this.book, this.now});

  final BookModel book;

  /// Saat bağımlılığı enjekte edilebilir: uygulama null bırakır ve gerçek
  /// saati kullanır; testler sabit saat vererek günün saatine göre değişen
  /// takvim günü hesaplarını (ör. gece 00:00-02:00 arası) kesinleştirir.
  final DateTime? now;

  static const List<String> _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clock = now ?? DateTime.now();
    final stats = ReadingStats.calculate(book.readingLog, now: clock);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                // Expanded: dar ekranlarda başlık taşmadan kırpılır.
                Expanded(
                  child: Text(
                    'Okuma İstatistikleri',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stats.events.isEmpty)
              Text(
                'Okumaya başlayıp konumunu güncelledikçe günlük okunan '
                'sayfa burada birikir.',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              _StatGrid(stats: stats),
              const SizedBox(height: 16),
              _DailyBars(daily: stats.daily, now: clock),
              const SizedBox(height: 16),
              Text('Son kayıtlar', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              ..._historyRows(theme, stats, clock),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _historyRows(ThemeData theme, ReadingStats stats, DateTime now) {
    final events = stats.events;
    final deltas = stats.eventDeltas;
    final start = events.length > 4 ? events.length - 4 : 0;

    final rows = <Widget>[];
    for (var i = events.length - 1; i >= start; i--) {
      final entry = events[i];
      final delta = deltas[i];
      final date = '${entry.at.day} ${_months[entry.at.month - 1]}'
          '${entry.at.year != now.year ? ' ${entry.at.year}' : ''}';
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(date, style: theme.textTheme.bodySmall),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Sayfa ${entry.page}',
                    style: theme.textTheme.bodyMedium),
              ),
              if (delta > 0)
                Text(
                  '+$delta sayfa',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}

/// 2x2 istatistik kutuları.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final ReadingStats stats;

  String get _avgLabel {
    final value = stats.avgPerDay;
    if (value == 0) return '0';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            _tile(theme, '${stats.totalPagesRead}', 'Okunan sayfa'),
            _tile(theme, _avgLabel, 'Günlük ortalama'),
          ],
        ),
        Row(
          children: [
            _tile(theme, '${stats.last7Days}', 'Son 7 gün'),
            _tile(
              theme,
              stats.bestDayPages > 0 ? '${stats.bestDayPages}' : '-',
              'En verimli gün',
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(ThemeData theme, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Son 14 günün mini bar grafiği; veri olmayan günler ince çizgi olur.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.daily, required this.now});

  final List<DailyReading> daily;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pagesByDay = {for (final d in daily) d.day: d.pages};
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(
      14,
      (i) => today.subtract(Duration(days: 13 - i)),
    );
    final maxPages = daily.isEmpty
        ? 0
        : daily.map((d) => d.pages).reduce((a, b) => a > b ? a : b);

    return Semantics(
      label: 'Son 14 günün günlük okuma grafiği',
      child: SizedBox(
        height: 84,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: _bar(theme, days[i], pagesByDay[days[i]] ?? 0, maxPages, i),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bar(
    ThemeData theme,
    DateTime day,
    int pages,
    int maxPages,
    int index,
  ) {
    final barHeight = pages <= 0
        ? 2.0
        : 2.0 + (pages / maxPages) * 56;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          key: ValueKey('daily-bar-$index'),
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: pages > 0
                ? theme.colorScheme.primary
                : theme.dividerColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(3),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${day.day}',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

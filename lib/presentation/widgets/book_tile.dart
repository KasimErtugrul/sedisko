import 'package:flutter/material.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/book_model.dart';
import '../../domain/services/reading_goal.dart';
import '../utils/app_haptics.dart';
import 'cover_image.dart';

/// Tüm liste kartlarında kullanılan zengin kitap satırı.
///
/// Kullanıcı isteğiyle kartlar artık kitaba ve rafa ilişkin tüm bilgileri
/// tek bakışta gösterir: kapak, başlık, yazar(lar), raf, yayınevi, basım
/// yılı, sayfa sayısı, okuma durumu/sayfa/tarihler ve varsa bitirme
/// hedefi (kalan gün + günlük sayfa planı ya da gecikme uyarısı).
///
/// **1.20.0 (keşke 15):** taşıma artık görünür düğmeyle de yapılır —
/// "taşıma uzun basma ile yapılıyor, kimse söylemedi" şeklindeki
/// kullanıcı notuna karşılık kartın ucundaki düğme aynı akışı açar;
/// uzun basma yolu da çalışmaya devam eder.
class BookTile extends StatelessWidget {
  const BookTile({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
  });

  final BookModel book;
  final VoidCallback onTap;

  /// Uzun basma: raf sayfası ve ana listede "başka rafa taşı" akışı için.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        onLongPress: onLongPress == null
            ? null
            : () {
                AppHaptics.selection();
                onLongPress!();
              },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CoverImage(url: book.coverUrl, path: book.coverPath),
                  if (book.isFavorite)
                    const Positioned(
                      top: 2,
                      right: 2,
                      child: _FavoriteBadge(),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (book.authors.isNotEmpty)
                      Text(
                        book.authorsText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _metaLine(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 6),
                    _statusBlock(theme),
                    if (_goalText() != null) ...[
                      const SizedBox(height: 4),
                      _goalLine(theme),
                    ],
                  ],
                ),
              ),
              // Keşke 15 (1.20.0): "başka rafa taşı" yolu artık görünür.
              // Uzun basma hâlâ aynı akışı açar; düğme onun keşfedilebilir
              // ikonu. Sağlarken uzun basmanın davranışı değişmedi.
              if (onLongPress != null)
                IconButton(
                  key: const ValueKey('book-tile-move'),
                  tooltip: 'Başka rafa taşı',
                  icon: const Icon(Icons.drive_file_move_outline),
                  onPressed: () {
                    AppHaptics.selection();
                    onLongPress!();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Raf + yayınevi + basım + sayfa sayısı özeti; olmayan alanlar atlanır.
  String _metaLine() {
    final parts = <String>[
      book.shelf.trim().isEmpty ? 'Rafsız' : 'Raf: ${book.shelf.trim()}',
      if (book.publisher != null && book.publisher!.trim().isNotEmpty)
        book.publisher!,
      if (book.publishDate != null && book.publishDate!.trim().isNotEmpty)
        'Basım: ${book.publishDate}',
      if (book.pageCount > 0) '${book.pageCount} sayfa',
    ];
    return parts.join(' • ');
  }

  /// Bitirme hedefi metni; hedef yoksa ya da anlamlı değilse `null`.
  /// Bitmemiş kitapta kalan gün (+ günlük plan/gecikme), bitmiş kitapta
  /// hedefe göre sonuç gösterilir.
  String? _goalText() {
    final target = book.targetFinishDate;
    if (target == null) return null;
    final now = DateTime.now();

    if (book.status == ReadingStatus.finished) {
      final diff = ReadingGoal.finishedAgainstTarget(book);
      if (diff == null) return null;
      if (diff > 0) return 'Hedefinden $diff gün önce bitirdin';
      if (diff < 0) return 'Hedefi ${-diff} gün aştın';
      return 'Hedef gününde bitti';
    }

    final days = ReadingGoal.daysLeft(target, now);
    if (days < 0) return 'Hedef: ${formatDate(target)} • ${-days} gün gecikti';
    if (days == 0) {
      return 'Hedef: bugün (${formatDate(target)})';
    }
    final perDay = ReadingGoal.pagesPerDay(book, now);
    return perDay == null
        ? 'Hedef: ${formatDate(target)} • $days gün kaldı'
        : 'Hedef: ${formatDate(target)} • $days gün • günde ~$perDay sayfa';
  }

  /// Hedef satırı; gecikmişse dikkat çekmek için hata rengiyle yazılır.
  Widget _goalLine(ThemeData theme) {
    final text = _goalText()!;
    final overdue =
        book.status != ReadingStatus.finished && ReadingGoal.isOverdue(
      book,
      DateTime.now(),
    );
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: overdue ? theme.colorScheme.error : null,
        fontWeight: overdue ? FontWeight.w600 : null,
      ),
    );
  }

  Widget _statusBlock(ThemeData theme) {
    final small = theme.textTheme.bodySmall;
    switch (book.status) {
      case ReadingStatus.notStarted:
        return Text('Henüz başlanmadı', style: small);
      case ReadingStatus.reading:
        final percent = (book.progress * 100).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (book.pageCount > 0)
              Semantics(
                label: 'Okuma ilerlemesi yüzde $percent',
                child: LinearProgressIndicator(value: book.progress),
              ),
            const SizedBox(height: 4),
            Text(
              book.pageCount > 0
                  ? 'Sayfa ${book.currentPage}/${book.pageCount} (%$percent)'
                  : 'Sayfa ${book.currentPage}',
              style: small,
            ),
            Text('Başlangıç: ${formatDate(book.startedAt)}', style: small),
          ],
        );
      case ReadingStatus.finished:
        return Text('Bitti • ${formatDate(book.finishedAt)}', style: small);
    }
  }
}

/// Kapak köşesindeki küçük favori işareti; ana sayfada favori listesinde
/// olmayan kitapların da favori durumunu listede görünür kılar.
class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.favorite,
        size: 14,
        color: Colors.redAccent,
      ),
    );
  }
}

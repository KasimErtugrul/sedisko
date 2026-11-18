import 'package:flutter/material.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/book_model.dart';
import '../utils/app_haptics.dart';
import 'cover_image.dart';

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
                    const SizedBox(height: 6),
                    _statusBlock(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
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

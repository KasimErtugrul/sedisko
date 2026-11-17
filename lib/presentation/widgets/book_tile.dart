import 'package:flutter/material.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/book_model.dart';
import 'cover_image.dart';

class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, required this.onTap});

  final BookModel book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(url: book.coverUrl),
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
            if (book.pageCount > 0) LinearProgressIndicator(value: book.progress),
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

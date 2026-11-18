import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/book_model.dart';
import '../../../domain/services/reading_goal.dart';
import '../../routes/app_routes.dart';
import '../cover_image.dart';

/// Zengin kapak kartı: kapak + başlık + yazar + durum/sayfa + raf.
///
/// Kart tüm bilgileri gösterir: favori işareti (kapak köşesinde), okuma
/// durumu ve sayfa ilerlemesi, raf adı. [emphasizeGoal] doğruysa raf
/// satırı yerine bitirme hedefi geri sayımı çıkar ("X gün kaldı" /
/// "N gün gecikti"; gecikmişse hata rengiyle).
///
/// Ana sayfanın tüm yatay şeritleri bu kartı paylaşır; kitaba dokununca
/// detay sayfası açılır.
class BookCoverCard extends StatelessWidget {
  const BookCoverCard({
    super.key,
    required this.book,
    required this.onTap,
    this.emphasizeGoal = false,
  });

  final BookModel book;
  final VoidCallback onTap;

  /// true: kart durumu yerine bitirme hedefi geri sayımını gösterir.
  final bool emphasizeGoal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    return SizedBox(
      width: 116,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 116,
                    height: 150,
                    child: CoverImage(
                      url: book.coverUrl,
                      path: book.coverPath,
                      width: 116,
                      height: 150,
                    ),
                  ),
                ),
                if (book.isFavorite)
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: _FavoriteBadge(),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (book.authors.isNotEmpty)
              Text(
                book.authorsText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: small?.copyWith(color: theme.colorScheme.outline),
              ),
            const SizedBox(height: 2),
            Text(
              _statusLine(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small,
            ),
            Text(
              emphasizeGoal
                  ? _goalCountdownLine()
                  : (book.shelf.trim().isEmpty
                      ? 'Rafsız'
                      : 'Raf: ${book.shelf.trim()}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small?.copyWith(
                color: _countdownColor(theme) ?? theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Durum/sayfa satırı: okunuyorsa ilerleme, bittiyse bitiş, başlanmadıysa
  /// sayfa sayısı (bilinmiyorsa durum etiketi).
  String _statusLine() {
    switch (book.status) {
      case ReadingStatus.reading:
        return book.pageCount > 0
            ? 'Sayfa ${book.currentPage}/${book.pageCount}'
            : 'Sayfa ${book.currentPage}';
      case ReadingStatus.finished:
        return 'Bitti • ${formatDate(book.finishedAt)}';
      case ReadingStatus.notStarted:
        return book.pageCount > 0
            ? '${book.pageCount} sayfa'
            : 'Henüz başlanmadı';
    }
  }

  /// Hedef şeridindeki geri sayım satırı.
  String _goalCountdownLine() {
    final target = book.targetFinishDate;
    if (target == null) return '';
    final days = ReadingGoal.daysLeft(target, DateTime.now());
    if (days < 0) return '${-days} gün gecikti';
    if (days == 0) return 'Hedef bugün';
    return '$days gün kaldı';
  }

  Color? _countdownColor(ThemeData theme) {
    if (!emphasizeGoal || book.targetFinishDate == null) return null;
    final days =
        ReadingGoal.daysLeft(book.targetFinishDate!, DateTime.now());
    if (days < 0) return theme.colorScheme.error;
    return null;
  }
}

/// Kapak köşesindeki küçük favori işareti.
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

/// Kartın varsayılan dokunuşu: kitap detay sayfası.
void openBookDetail(BookModel book) =>
    Get.toNamed(Routes.detail, arguments: book.id);

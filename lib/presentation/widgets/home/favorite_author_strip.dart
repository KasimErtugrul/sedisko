import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/services/home_feed.dart';
import '../../routes/app_routes.dart';
import '../../routes/route_args.dart';

/// "Favori yazarlar" yatay şeridi (1.16.0, kullanıcı isteği).
///
/// Raf düzeni asistanında seçilen favori yazarlar artık ana sayfada da
/// görünür: her kart yıldız rozetli avatar + yazar adı + kitap sayısı
/// gösterir. Karta dokununca yazarın kitapları raf sayfasında açılır
/// (yazar detay görünümü); kitabı olmayan favori yazar "kitaplıkta yok"
/// etiketiyle yine de listede kalır — tercih ettiği yazarını görmek ister.
///
/// Kartlar [AuthorStrip]'in kartlarıyla aynı hedefe gider; görsel fark
/// yıldız avatarıdır (en çok kitaba sahip yazarlar sıralamasından ayrışır).
class FavoriteAuthorStrip extends StatelessWidget {
  const FavoriteAuthorStrip({super.key, required this.authors});

  final List<AuthorSummary> authors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: authors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final author = authors[index];
          return _FavoriteAuthorCard(
            key: ValueKey('home-favorite-author-${author.key}'),
            author: author,
          );
        },
      ),
    );
  }
}

class _FavoriteAuthorCard extends StatelessWidget {
  const _FavoriteAuthorCard({super.key, required this.author});

  final AuthorSummary author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 112,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => Get.toNamed(
            Routes.shelf,
            arguments: ShelfArgs(authorKey: author.key),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Yıldız avatarı: favori kartını normal yazar kartından
                // ayırt eder.
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: Icon(
                    Icons.star,
                    size: 22,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  author.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  author.bookCount > 0
                      ? '${author.bookCount} kitap'
                      : 'Kitaplıkta yok',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

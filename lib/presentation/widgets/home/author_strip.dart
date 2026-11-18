import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/services/home_feed.dart';
import '../../routes/app_routes.dart';
import '../../routes/route_args.dart';

/// "En çok kitaba sahip yazarlar" yatay şeridi.
///
/// Her kart: baş harf avatarı + yazar adı + kitap sayısı. Karta dokununca
/// yazarın kitapları raf sayfasında açılır (Yazarlar sekmesindeki kartla
/// aynı hedef); sekme başlığındaki "Tümü" aksiyonu Yazarlar sekmesine
/// geçirir (bkz. [HomePage] geri çağrıları).
class AuthorStrip extends StatelessWidget {
  const AuthorStrip({super.key, required this.authors});

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
          return _AuthorCard(
            key: ValueKey('home-author-${author.key}'),
            author: author,
          );
        },
      ),
    );
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({super.key, required this.author});

  final AuthorSummary author;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Baş harf olduğu gibi kullanılır: Türkçe I/İ dönüşümü yanlış harf
    // üretebilir ('i'.toUpperCase() → 'I'), bu yüzden dönüştürülmez.
    final initial = author.name.isEmpty ? '?' : author.name.characters.first;

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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(
                    initial,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
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
                  '${author.bookCount} kitap',
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

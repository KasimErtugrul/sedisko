/// Ana sayfa "Satın alınacaklar" bölümü için yatay şerit.
///
/// 1.18.0: Satın alınacaklar listesindeki kayıtları kitap şeritleriyle
/// aynı dilde gösterir: yatay kayan sade kartlar (başlık iki satır,
/// yazar altında küçük). Kaynak rozeti bilinçli olarak konmaz; şerit
/// temiz kalır. Karta dokunulduğunda [onTapItem] tetiklenir.
library;

import 'package:flutter/material.dart';

import '../../../data/models/wishlist_item_model.dart';

class WishlistStrip extends StatelessWidget {
  const WishlistStrip({super.key, required this.items, this.onTapItem});

  final List<WishlistItemModel> items;

  final void Function(WishlistItemModel item)? onTapItem;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _ItemCard(
            key: ValueKey('wishlist-strip-${item.id}'),
            item: item,
            onTap: onTapItem == null ? null : () => onTapItem!(item),
          );
        },
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final WishlistItemModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final authorsText = item.authors.join(', ');

    return SizedBox(
      width: 148,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                if (authorsText.isNotEmpty)
                  Text(
                    authorsText,
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

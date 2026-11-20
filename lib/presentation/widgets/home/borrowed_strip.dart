import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/borrowed_book_model.dart';

/// "Ödünç aldıkların" yatay şeridi (1.18.0).
///
/// Her kart: kitap adı + 'Sahibi: X' + alım tarihi. Ana sayfa bölüm
/// gövdesi olarak kullanılır; dokunuş [onTap] ile çağırana iletilir
/// (hedef sayfayı bağlayan entegratör belirler). Şerit ana akışın
/// dikey ListView'ı içinde tek satır kaplar ve yatayda bağımsız kayar.
class BorrowedStrip extends StatelessWidget {
  const BorrowedStrip({super.key, required this.borrowed, this.onTap});

  final List<BorrowedBookModel> borrowed;

  final void Function(BorrowedBookModel item)? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: borrowed.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = borrowed[index];
          return _BorrowedCard(
            key: ValueKey('borrowed-strip-${item.id}'),
            item: item,
            onTap: () => onTap?.call(item),
          );
        },
      ),
    );
  }
}

class _BorrowedCard extends StatelessWidget {
  const _BorrowedCard({super.key, required this.item, required this.onTap});

  final BorrowedBookModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 148,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sahibi: ${item.owner}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'alındı: ${formatDate(item.borrowedAt)}',
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

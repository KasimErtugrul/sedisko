import 'package:flutter/material.dart';

/// "Rafların" bölümünün tek karta indirgenmiş raf özeti.
class ShelfSummary {
  const ShelfSummary({
    required this.key,
    required this.total,
    required this.reading,
    required this.finished,
  });

  /// Raf anahtarı; 'Rafsız' anahtarı rafsız kitapları seçer.
  final String key;
  final int total;
  final int reading;
  final int finished;
}

/// Ana sayfanın "Rafların" grid bölümü.
///
/// Kullanıcı isteği: ana sayfa yalnız yatay listelerden değil, gridview'lerden
/// de beslensin. Raf kartları iki kolonlu, içi kaymayan bir grid olarak
/// yerleşir; dikey kaydırmayı ana akış sağlar. Karta dokununca rafın kitap
/// listesi açılır ('Rafsız' anahtarı rafsız kitapları gösterir).
///
/// Anahtarlar 'shelf-card-…' ile çakışmasın diye 'home-shelf-card-…'
/// kullanılır (Raflar sekmesindeki kartlar ayrıdır).
class ShelfSummaryGrid extends StatelessWidget {
  const ShelfSummaryGrid({
    super.key,
    required this.shelves,
    required this.onOpen,
  });

  final List<ShelfSummary> shelves;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.9,
      ),
      itemCount: shelves.length,
      itemBuilder: (context, index) {
        final shelf = shelves[index];
        return _ShelfCard(
          key: ValueKey('home-shelf-card-${shelf.key}'),
          shelf: shelf,
          onOpen: onOpen,
        );
      },
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({super.key, required this.shelf, required this.onOpen});

  final ShelfSummary shelf;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final details = <String>[
      if (shelf.reading > 0) '${shelf.reading} okunuyor',
      if (shelf.finished > 0) '${shelf.finished} bitti',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => onOpen(shelf.key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shelves,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      shelf.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${shelf.total} kitap',
                    style: small?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
              if (details.isNotEmpty)
                Text(
                  details.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Kitaplık tamamen boşken ana sayfanın yönlendirici boş durumu.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key, required this.hasBooks});

  final bool hasBooks;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasBooks ? Icons.search_off : Icons.library_books_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasBooks
                  ? 'Aramana uyan kitap yok.'
                  : 'Kitaplığın boş.\nİlk kitabını barkod tarayarak ekle.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (hasBooks)
              Text(
                'Durum çipleriyle daraltabilirsin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

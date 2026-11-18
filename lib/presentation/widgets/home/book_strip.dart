import 'package:flutter/material.dart';

import '../../../data/models/book_model.dart';
import 'book_cover_card.dart';

/// Yatay kapak şeridi; ana sayfa kitap bölümlerinin ortak gövdesi.
///
/// Yükseklik sabittir (kapak 150 + metin bloğu); şerit ana akışın
/// dikey ListView'ı içinde tek satır kaplar ve yatayda bağımsız kayar.
class BookStrip extends StatelessWidget {
  const BookStrip({super.key, required this.books, this.emphasizeGoal = false});

  final List<BookModel> books;

  /// true: kartlarda raf satırı yerine hedef geri sayımı gösterilir.
  final bool emphasizeGoal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 252,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final book = books[index];
          return BookCoverCard(
            key: ValueKey('strip-${book.id}'),
            book: book,
            emphasizeGoal: emphasizeGoal,
            onTap: () => openBookDetail(book),
          );
        },
      ),
    );
  }
}

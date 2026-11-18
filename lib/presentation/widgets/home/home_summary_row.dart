import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/library_controller.dart';

/// Ana sayfanın özet satırı: toplam / okunuyor / bitti / favori sayıları.
///
/// Ana akış zaten bir [Obx] içinde kurulduğu için burada ek dinleyici
/// gerekmez; kitaplık değişince satır yeniden kurulur.
class HomeSummaryRow extends GetView<LibraryController> {
  const HomeSummaryRow({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget stat(String value, String label, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(31),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          stat('${controller.books.length}', 'Toplam', scheme.primary),
          const SizedBox(width: 8),
          stat('${controller.readingCount}', 'Okunuyor', Colors.orange),
          const SizedBox(width: 8),
          stat('${controller.finishedCount}', 'Bitti', Colors.green),
          const SizedBox(width: 8),
          stat('${controller.favoriteBooks.length}', 'Favori', Colors.redAccent),
        ],
      ),
    );
  }
}

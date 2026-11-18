import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/library_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';

/// 'Raflar' sekmesi: yatay raf kartları.
///
/// Raflar, ad + kitap sayısı gösteren yatay kaydırılabilir kartlar halinde.
/// Karta dokununca o rafın kitapları ayrı bir sayfada açılır ([Routes.shelf]).
/// Kitap arama ve ekleme ana sayfa sekmesindedir.
class ShelvesPage extends GetView<LibraryController> {
  const ShelvesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raflar')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.books.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_books_outlined, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'Kitaplığın boş.\nİlk kitabını ana sayfadan ekle.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return _shelfStrip(context);
      }),
    );
  }

  /// Yatay raf kartları: 'Tüm kitaplar' + dolu raflar + varsa 'Rafsız'.
  /// Kartlar zengin özet taşır: kitap sayısı + okunuyor + bitti kırılımı.
  Widget _shelfStrip(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        SizedBox(
          height: 178,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: controller.shelfKeys.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ShelfCard(
                  key: const ValueKey('shelf-card-all'),
                  icon: Icons.auto_stories,
                  name: 'Tüm kitaplar',
                  count: controller.books.length,
                  readingCount: controller.readingCount,
                  finishedCount: controller.finishedCount,
                  onTap: () =>
                      Get.toNamed(Routes.shelf, arguments: const ShelfArgs()),
                );
              }
              final key = controller.shelfKeys[index - 1];
              return _ShelfCard(
                key: ValueKey('shelf-card-$key'),
                icon: key == 'Rafsız' ? Icons.folder_off_outlined : Icons.shelves,
                name: key,
                count: controller.shelfCount(key),
                readingCount: controller.shelfReadingCount(key),
                finishedCount: controller.shelfFinishedCount(key),
                onTap: () => Get.toNamed(
                  Routes.shelf,
                  arguments: ShelfArgs(shelf: key),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          child: Text(
            'Bir rafa dokunarak o raftaki kitapları açabilirsin.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Zengin yatay raf kartı: raf adı + kitap sayısı + okunuyor/bitti kırılımı.
class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    super.key,
    required this.icon,
    required this.name,
    required this.count,
    required this.readingCount,
    required this.finishedCount,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final int count;
  final int readingCount;
  final int finishedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 158,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: scheme.primary),
                const Spacer(),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('$count kitap', style: small),
                // Kırılım satırı: okunuyor/bitti bilinen kadar gösterilir;
                // ikisi de yoksa satır yer tutmaz.
                if (readingCount > 0)
                  Text(
                    '$readingCount okunuyor',
                    style: small?.copyWith(color: Colors.orange.shade700),
                  ),
                if (finishedCount > 0)
                  Text(
                    '$finishedCount bitti',
                    style: small?.copyWith(color: Colors.green.shade700),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

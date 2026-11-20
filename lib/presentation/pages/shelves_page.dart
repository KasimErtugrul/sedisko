import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/library_controller.dart';
import '../controllers/shelf_organize_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';

/// 'Raflar' sekmesi: iki kolonlu raf grid'i + düzenleme asistanı girişi.
///
/// Kullanıcı isteği (1.16.0): raflar yatay kaydırmalı şerit yerine grid
/// view ile görünsün — tüm raflar tek bakışta, dikey kaydırma doğal.
/// Karta dokununca o rafın kitapları ayrı bir sayfada açılır ([Routes.shelf]).
/// Üstte taşıma planı sürüyorsa ilerleme bandı, yoksa "Otomatik düzenle"
/// kartı gösterilir; uygulama çubuğundan raf düzenleyiciye gidilir.
class ShelvesPage extends GetView<LibraryController> {
  const ShelvesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raflar'),
        actions: [
          if (Get.isRegistered<ShelfOrganizeController>())
            // 1.21.0: yazılı çubuk düğmesi denendi; dar ekranda (360dp,
            // 1.3 metin ölçeği) "Raflar" başlığını 7 piksele sıkıştırdığı
            // için çubukta tooltip'li ikon korunur. Yazılı giriş asistan
            // kurulum kartındadır.
            IconButton(
              key: const ValueKey('shelves-open-editor'),
              tooltip: 'Rafları düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Get.toNamed(Routes.shelfEditor),
            ),
        ],
      ),
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

  /// Raf grid'i: 'Tüm kitaplar' + dolu raflar + varsa 'Rafsız'.
  /// Üstte asistan kartı: plan sürüyorsa ilerleme, değilse davet.
  Widget _shelfStrip(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (Get.isRegistered<ShelfOrganizeController>()) _OrganizeEntry(),
        // Kullanıcı isteği (1.16.0): raflar grid view. Dikey kaydırmayı
        // dış ListView sağlar; grid içi kaymaz (ana akışla aynı desen).
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
          ),
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

/// Düzenleme asistanı girişi: plan sürüyorsa ilerleme bandı; yoksa davet
/// kartı. Denetleyici test ortamında kayıtlı olmayabilir; o zaman kart
/// hiç gösterilmez (mevcut testler etkilenmez).
class _OrganizeEntry extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ShelfOrganizeController>();
    return Obx(() {
      final plan = controller.plan.value;
      final scheme = Theme.of(context).colorScheme;
      return Card(
        key: const ValueKey('organize-entry'),
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Get.toNamed(
            plan == null ? Routes.organizeSetup : Routes.organizePlan,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  plan == null ? Icons.auto_awesome : Icons.route,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: plan == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rafları otomatik düzenle',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Yazara, yayınevine, ada ya da sayfa sayısına '
                              'göre dağıt; taşma yok.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Taşıma planı sürüyor',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${plan.completedCount}/${plan.turs.length} tur '
                              'tamam — devam etmek için dokun.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Zengin raf kartı (grid hücresi): raf adı + kitap sayısı +
/// okunuyor/bitti kırılımı.
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
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
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
    );
  }
}

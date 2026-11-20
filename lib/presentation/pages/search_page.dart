/// Open Library başlık/yazar arama sayfası.
///
/// 1.18.0: "Kitap ekle" akışının yeni yolu. Kullanıcı kitap adı ve/veya
/// yazar yazıp arar; her sonuçta iki aksiyon vardır:
/// - "Kitaplığa ekle": kitap formunu arama bilgileriyle doldurulmuş açar.
/// - "Satın alma listesine ekle": kaydı satın alınacaklar listesine yazar.
///
/// Arama denetleyicisi rota kaydında lazyPut ile bağlanır; sayfa yalnızca
/// `Get.find` ile erişir. Satın alma listesi denetleyicisi (InitialBinding)
/// kayıtlı değilse liste aksiyonu gizlenir.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/open_library_search_result.dart';
import '../controllers/openlibrary_search_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';

class SearchPage extends GetView<OpenLibrarySearchController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Open Library'de ara")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: controller.titleCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => controller.search(),
                  decoration: const InputDecoration(
                    labelText: 'Kitap adı',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller.authorCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => controller.search(),
                  decoration: const InputDecoration(
                    labelText: 'Yazar',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Ara'),
                    onPressed: controller.search,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Obx(() => _resultsArea(context))),
        ],
      ),
    );
  }

  Widget _resultsArea(BuildContext context) {
    if (controller.searching.value) {
      return const Center(child: CircularProgressIndicator());
    }

    final errorText = controller.error.value;
    if (errorText.isNotEmpty) {
      return _WarningCard(message: errorText);
    }

    if (controller.searched.value && controller.results.isEmpty) {
      return const _MessageView(
        icon: Icons.search_off,
        message: 'Sonuç bulunamadı. Farklı sözcüklerle deneyin.',
      );
    }

    final results = controller.results;
    if (results.isEmpty) {
      return const _MessageView(
        icon: Icons.travel_explore,
        message: 'Kitap adı veya yazar yazıp arayın.',
      );
    }

    final wishlist = Get.isRegistered<WishlistController>()
        ? Get.find<WishlistController>()
        : null;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _ResultCard(
        result: results[index],
        wishlist: wishlist,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.wishlist});

  final OpenLibrarySearchResult result;
  final WishlistController? wishlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final metaParts = <String>[
      if (result.firstPublishYear != null) result.firstPublishYear.toString(),
      if (result.publishers.isNotEmpty) result.publishers.first,
      if (result.pageCount != null && result.pageCount! > 0)
        '${result.pageCount} s.',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Cover(url: result.coverUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (result.authors.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            result.authors.join(', '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      if (metaParts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            metaParts.join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Get.toNamed(
                      Routes.form,
                      arguments: BookFormArgs(book: result.toBook()),
                    ),
                    child: const Text('Kitaplığa ekle'),
                  ),
                ),
                if (wishlist != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await wishlist!.addFromSearch(result);
                        if (!ok) return;
                        Get.snackbar(
                          'Satın alma listesine eklendi',
                          result.title,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      child: const Text(
                        'Satın alma listesine ekle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 56x80 kapak kutusu; ağ görseli yüklenemezse/ yoksa kitap ikonu.
class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final u = url;
    if (u == null || u.isEmpty) return _box(scheme);
    return SizedBox(
      width: 56,
      height: 80,
      child: Image.network(
        u,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _box(scheme),
      ),
    );
  }

  Widget _box(ColorScheme scheme) {
    return Container(
      width: 56,
      height: 80,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.menu_book,
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(16),
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

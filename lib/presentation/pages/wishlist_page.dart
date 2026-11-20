/// Satın alınacaklar sayfası.
///
/// 1.18.0: Open Library aramasından veya elle eklenen, alınmak istenen
/// kitapların listesi. Kart dokunuşu düzenleme diyaloğu açar; çöp ikonu
/// onaylı silme yapar; alttaki düğme kaydı doldurulmuş kitap formuna
/// taşır. AppBar'daki arama ikonu Open Library arama sayfasını açar.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/wishlist_item_model.dart';
import '../controllers/wishlist_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../widgets/cover_image.dart';
import '../widgets/wishlist_item_dialog.dart';

class WishlistPage extends GetView<WishlistController> {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Satın alınacaklar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Open Library'de ara",
            onPressed: () => Get.toNamed(Routes.search),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Elle ekle'),
        onPressed: () => _addItem(context),
      ),
      body: Obx(() {
        final items = controller.items;
        if (items.isEmpty) {
          return const _MessageView(
            icon: Icons.shopping_bag_outlined,
            message: 'Henüz satın alınacak kitap yok.\n'
                'Open Library aramasından ya da "Elle ekle" ile ekleyebilirsin.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _ItemCard(key: ValueKey('wishlist-${items[index].id}'), item: items[index]),
        );
      }),
    );
  }

  Future<void> _addItem(BuildContext context) async {
    final result = await showWishlistItemDialog(context);
    if (result == null) return;
    final (title, authors, note) = result;
    await controller.add(
      WishlistItemModel(
        id: WishlistItemModel.newId(),
        title: title,
        authors: _splitAuthors(authors),
        note: note.isEmpty ? null : note,
        addedAt: DateTime.now(),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({super.key, required this.item});

  final WishlistItemModel item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final metaParts = <String>[
      if (item.publisher != null && item.publisher!.isNotEmpty) item.publisher!,
      if (item.pageCount > 0) '${item.pageCount} s.',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editItem(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoverImage(url: item.coverUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (item.authors.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.authors.join(', '),
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
                        if (item.note != null && item.note!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Not: ${item.note}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        _SourceBadge(label: item.source.label),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Listeden çıkar',
                    onPressed: () => _confirmRemove(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Keşke 36 (1.20.0): "Kitabı aldım, kitaplığa ekledim;
              // listede durmaya devam etti. 'Aldım' düğmesi olsaydı" —
              // iki net yol yan yana.
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: ValueKey('wishlist-bought-${item.id}'),
                        onPressed: () => _confirmBought(context),
                        icon: const Icon(Icons.check),
                        label: const Text('Aldım'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => Get.toNamed(
                          Routes.form,
                          arguments: BookFormArgs(book: item.toBook()),
                        ),
                        child: const Text('Kitaplığa ekle'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 'Aldım': kayıt onayla listeden çıkarılır. Kitabı kitaplığa ekleme
  /// yoluna dokunulmaz; diyalog yolu da hatırlatır.
  Future<void> _confirmBought(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('"${item.title}" alındı mı?'),
        content: const Text(
          'Aldım işareti kaydı listeden çıkarır. Kitabı kitaplığa da '
          'eklemek istersen "Kitaplığa ekle" düğmesini kullan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const ValueKey('wishlist-bought-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Evet, aldım'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Get.find<WishlistController>().remove(item.id);
    Get.snackbar(
      'Aldım olarak işaretlendi',
      '"${item.title}" listeden çıkarıldı.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _editItem(BuildContext context) async {
    final result = await showWishlistItemDialog(context, existing: item);
    if (result == null) return;
    final (title, authors, note) = result;
    await Get.find<WishlistController>().updateItem(
      item.copyWith(
        title: title,
        authors: _splitAuthors(authors),
        note: note.isEmpty ? null : note,
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('"${item.title}" listeden çıkarılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Get.find<WishlistController>().remove(item.id);
    }
  }
}

/// Kaynağı gösteren küçük rozet ('Open Library' / 'Manuel').
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.labelSmall,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: scheme.secondaryContainer,
      side: BorderSide.none,
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

List<String> _splitAuthors(String raw) => raw
    .split(',')
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

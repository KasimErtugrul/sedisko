import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/shelf_model.dart';
import '../controllers/shelf_organize_controller.dart';
import '../routes/app_routes.dart';
import '../widgets/organize/capacity_bar.dart';

/// Raf tanımlarının düzenlendiği sayfa: ad + kapasite (kitap sayısı) +
/// serbest yer etiketi ('Alt kat', 'Üst kat', …) + fiziksel sıra.
///
/// Hızlı kurulum tek kapasiteyle tüm rafları açar; tek tek düzenleme
/// her rafı gerçek kitaplığına göre ayarlar. Sıra, taşıma planının
/// gezinti düzenidir: plan rafları bu sırayla dizer.
class ShelfEditorPage extends StatelessWidget {
  const ShelfEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ShelfOrganizeController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rafları düzenle'),
        actions: [
          IconButton(
            key: const ValueKey('shelf-editor-quick-setup'),
            tooltip: 'Hızlı kurulum',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _quickSetupDialog(context, controller),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.shelves.isEmpty) {
          return const _EmptyEditor();
        }
        // Kalınlık tercihi değişirse kartlar da yenilensin (bağımlılık).
        final thicknessAware = controller.thicknessAware.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: [
            Text(
              'Kapasiteler gerçek kitaplığına göre olsun: plan hiçbir rafı '
              'kapasitesinin üzerine doldurmaz. "Yer" etiketi kat/oda adıdır; '
              'aynı etiketli rafların işi taşıma planında tek turda toplanır.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final shelf in controller.shelves)
              _ShelfCard(shelf: shelf, thicknessAware: thicknessAware),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('shelf-editor-add'),
        onPressed: () =>
            showShelfEditDialog(context, controller, null),
        icon: const Icon(Icons.add),
        label: const Text('Raf ekle'),
      ),
    );
  }

  Future<void> _quickSetupDialog(
    BuildContext context,
    ShelfOrganizeController controller,
  ) async {
    final input = TextEditingController(
      text: '${ShelfOrganizeController.defaultCapacity}',
    );
    final count = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hızlı kurulum'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Her raf kaç kitap alır?',
            hintText: 'örn. 50',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const ValueKey('quick-setup-submit'),
            onPressed: () {
              final value = int.tryParse(input.text.trim()) ?? 0;
              Navigator.pop(dialogContext, value >= 1 ? value : null);
            },
            child: const Text('Rafları aç'),
          ),
        ],
      ),
    );
    if (count != null) {
      await controller.quickSetup(count);
    }
  }
}

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shelves, size: 64),
            const SizedBox(height: 12),
            const Text(
              'Henüz raf tanımı yok.\n'
              'Hızlı kurulumla tek sayıda kapasite girip tüm rafları '
              'açabilir ya da tek tek ekleyebilirsin.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('shelf-editor-empty-quick'),
              onPressed: () => Get.toNamed(Routes.organizeSetup),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Hızlı kurulumla başla'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek raf kartı: ad, kapasite, yer, doluluk ve sıra düzenleme.
class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.shelf, required this.thicknessAware});

  final ShelfModel shelf;

  /// Kalınlık hesabı açıkken doluluk birim cinsinden gösterilir.
  final bool thicknessAware;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ShelfOrganizeController>();
    final isFavorite = controller.effectiveFavoriteShelf?.id == shelf.id;
    return Card(
      key: ValueKey('shelf-row-${shelf.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                shelf.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isFavorite)
              Icon(
                Icons.star,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: 'Favori raf',
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (shelf.location.isNotEmpty)
              Text('Yer: ${shelf.location}', maxLines: 1),
            const SizedBox(height: 6),
            if (thicknessAware)
              CapacityBar(
                key: ValueKey('shelf-bar-${shelf.id}'),
                count: controller.shelfHalfUnits(shelf.name),
                capacity: shelf.capacity * 2,
                dense: true,
                valueText: controller.shelfOccupancyText(shelf.name, shelf.capacity),
              )
            else
              CapacityBar(
                key: ValueKey('shelf-bar-${shelf.id}'),
                count: controller.shelfCount(shelf.name),
                capacity: shelf.capacity,
                dense: true,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Yukarı taşı',
              icon: const Icon(Icons.arrow_upward),
              onPressed: () => controller.moveShelf(shelf.id, -1),
            ),
            IconButton(
              tooltip: 'Aşağı taşı',
              icon: const Icon(Icons.arrow_downward),
              onPressed: () => controller.moveShelf(shelf.id, 1),
            ),
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  showShelfEditDialog(context, controller, shelf),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yeni raf / raf düzenleme diyaloğu. [shelf] `null` ise yeni raf açar.
/// Ad benzersizliği (aksan/büyük harf duyarsız) ve kapasite ≥ 1 denetlenir.
Future<void> showShelfEditDialog(
  BuildContext context,
  ShelfOrganizeController controller,
  ShelfModel? shelf,
) async {
  final nameCtrl = TextEditingController(text: shelf?.name ?? '');
  final capacityCtrl = TextEditingController(
    text: shelf == null
        ? '${ShelfOrganizeController.defaultCapacity}'
        : '${shelf.capacity}',
  );
  final locationCtrl = TextEditingController(text: shelf?.location ?? '');
  String? error;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        Future<void> submit() async {
          final name = nameCtrl.text.trim();
          final capacity = int.tryParse(capacityCtrl.text.trim()) ?? 0;
          if (!controller.isNameUsable(name, exceptId: shelf?.id)) {
            setState(() => error =
                name.trim().isEmpty ? 'Raf adı gerekli' : 'Bu raf zaten var');
            return;
          }
          if (capacity < 1) {
            setState(() => error = 'Kapasite en az 1 olmalı');
            return;
          }
          final ok = shelf == null
              ? await controller.addShelf(
                  name: name,
                  capacity: capacity,
                  location: locationCtrl.text,
                )
              : await controller.updateShelf(
                  id: shelf.id,
                  name: name,
                  capacity: capacity,
                  location: locationCtrl.text,
                );
          if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
        }

        return AlertDialog(
          title: Text(shelf == null ? 'Yeni raf' : 'Rafı düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: shelf == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Raf adı',
                    hintText: 'örn. Salon - 2. raf',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kapasite (kitap sayısı)',
                    hintText: 'örn. 50',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Yer (kat/oda)',
                    hintText: 'örn. Alt kat',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (shelf != null)
              TextButton(
                onPressed: () async {
                  await controller.removeShelf(shelf.id);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Sil'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: submit,
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    ),
  );
}

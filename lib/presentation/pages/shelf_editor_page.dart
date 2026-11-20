import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/shelf_model.dart';
import '../controllers/shelf_organize_controller.dart';
import '../routes/app_routes.dart';
import '../widgets/organize/capacity_bar.dart';

/// Raf tanımlarının düzenlendiği sayfa: ad + cm uzunluk + serbest yer
/// etiketi ('Alt kat', 'Üst kat', …) + fiziksel sıra.
///
/// **1.19.0:** her raf kartının solunda 1, 2, 3… numarası vardır —
/// düzen planı 1. raftan başlayıp sırayla dizer; kullanıcı hangi raftan
/// başlanacağını tek bakışta anlar. Uzunluk cm cinsindendir: kitapların
/// kalınlığı sayfa sayısından hesaplanır (420 sayfa ≈ 3 cm, 130 sayfa
/// ≈ 1 cm) ve plan hiçbir rafı uzunluğunun üzerine doldurmaz.
/// Hızlı kurulum tek uzunlukla tüm rafları açar; tek tek düzenleme
/// her rafı gerçek kitaplığına göre ayarlar. Sıra, taşıma planının
/// gezinti düzenidir: plan rafları bu sırayla dizer.
///
/// **1.19.3:** raf ataması ad bazlı olduğundan tanım adları
/// kitaplardaki adlarla birebir aynı olmalıdır. Kitaplarda olup tanımı
/// olmayan adlar üstteki uyarı kartında listelenir; raf diyaloğu bu
/// adları tek dokunuşla doldurulabilir öneri çipi olarak sunar
/// (kullanıcı 'Koridor 1' yazıp kitapların 'Koridor Raf 1' adını
/// gözden kaçırmıştı; eşleşmeyen tek kart 'Tv uzeri' ≡ 'Tv Üzeri'
/// katlamasıydı).
class ShelfEditorPage extends StatelessWidget {
  const ShelfEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ShelfOrganizeController>();
    return Scaffold(
      appBar: AppBar(
        // Keşke 21 (1.24.0): sayfa başlığı artık "Raf tanımları" —
        // asistan ("Rafları otomatik düzenle") ile kelime kelime
        // ayrışır; Raflar sekmesi çubuğundaki tooltip ve asistan
        // kurulumundaki düğme de aynı adı taşır: bir yerin adı her
        // yerde aynıdır.
        title: const Text('Raf tanımları'),
        actions: [
          // 1.21.0: yazılı çubuk düğmesi denendi; dar ekranda sayfa
          // başlığını sıkıştırdığı için tooltip'li ikon korunur. Hızlı
          // kurulumun yazılı yolu boş durum kartında zaten durur
          // ("Hızlı kurulumla başla").
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: [
            // 1.19.3: kitaplarda olup tanımı olmayan raf adları varsa
            // en üstte acil uyarı — plan yalnız tanımlı rafları kullanır.
            if (controller.unmatchedBookShelfNames().isNotEmpty)
              _MismatchBanner(controller.unmatchedBookShelfNames()),
            Text(
              'Uzunluklar gerçek rafta kitapların dizildiği boşluk olsun: '
              'plan hiçbir rafı uzunluğunun üzerine doldurmaz. Sol '
              'taraftaki numara düzen sırasıdır; plan 1. raftan başlar. '
              '"Yer" etiketi kat/oda adıdır; aynı etiketli rafların işi '
              'taşıma planında tek turda toplanır.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // Sol taraftaki 1, 2, 3… numarası fiziksel düzen sırasıdır:
            // plan kitapları 1. raftan itibaren sırayla dizer.
            for (var i = 0; i < controller.shelves.length; i++)
              _ShelfCard(shelf: controller.shelves[i], orderNumber: i + 1),
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
      text: '${ShelfOrganizeController.defaultShelfLengthCm}',
    );
    final lengthCm = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hızlı kurulum'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Her raf kaç cm uzunluğunda?',
            hintText: 'örn. 100',
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
    if (lengthCm != null) {
      await controller.quickSetup(lengthCm);
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
              'Hızlı kurulumla tek cm uzunluk girip tüm rafları '
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

/// 1.19.3: kitapların rafta kayıtlı olduğu ama tanımı olmayan adlar.
/// Düzen planı yalnız tanımlı rafları kullanır; adlar birebir aynı
/// değilse doluluklar 0 görünür, plan kitapları tanım adlarına
/// dağıtır ve çıktı gerçek kitaplıkla tutmaz.
class _MismatchBanner extends StatelessWidget {
  const _MismatchBanner(this.names);

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('shelf-editor-mismatch-banner'),
      margin: const EdgeInsets.only(bottom: 8),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Raf adları kitaplarla eşleşmiyor',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onErrorContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Kitaplar şu raf adlarında kayıtlı ama bu adlarda tanım '
              'yok: ${names.join(', ')}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Düzen planı yalnız buradaki tanımları kullanır; adlar '
              'birebir aynı değilse doluluklar 0 görünür ve plan '
              'kitapları tanım adlarına dağıtır. Kalem simgesiyle '
              'tanım adını kitaplardakiyle birebir aynı yap.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek raf kartı: SOL tarafta düzen sıra numarası, ad, cm uzunluk, yer,
/// doluluk ve sıra düzenleme.
class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    required this.shelf,
    required this.orderNumber,
  });

  final ShelfModel shelf;

  /// Bu rafın fiziksel düzen sırası (1'den başlar); plan kitapları bu
  /// sırayla dizer.
  final int orderNumber;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ShelfOrganizeController>();
    final isFavorite = controller.effectiveFavoriteShelf?.id == shelf.id;
    return Card(
      key: ValueKey('shelf-row-${shelf.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          key: ValueKey('shelf-order-${shelf.id}'),
          radius: 14,
          child: Text(
            '$orderNumber',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
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
            Text('${shelf.lengthCm} cm', maxLines: 1),
            if (shelf.location.isNotEmpty)
              Text('Yer: ${shelf.location}', maxLines: 1),
            const SizedBox(height: 6),
            CapacityBar(
              key: ValueKey('shelf-bar-${shelf.id}'),
              count: controller.shelfMm(shelf.name),
              capacity: shelf.lengthMm,
              dense: true,
              valueText: controller.shelfOccupancyText(shelf.name),
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
/// Ad benzersizliği (aksan/büyük harf duyarsız) ve uzunluk ≥ 1 cm
/// denetlenir.
Future<void> showShelfEditDialog(
  BuildContext context,
  ShelfOrganizeController controller,
  ShelfModel? shelf,
) async {
  final nameCtrl = TextEditingController(text: shelf?.name ?? '');
  final lengthCtrl = TextEditingController(
    text: shelf == null
        ? '${ShelfModel.defaultLengthCm}'
        : '${shelf.lengthCm}',
  );
  final locationCtrl = TextEditingController(text: shelf?.location ?? '');
  String? error;
  // 1.19.3: kitaplarda olup tanımı olmayan adlar — doğru adı yazmak
  // yerine tek dokunuşla seçebilsin (raf ataması ad bazlıdır).
  final suggestions = controller.unmatchedBookShelfNames();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        Future<void> submit() async {
          final name = nameCtrl.text.trim();
          final lengthCm = int.tryParse(lengthCtrl.text.trim()) ?? 0;
          if (!controller.isNameUsable(name, exceptId: shelf?.id)) {
            setState(() => error =
                name.trim().isEmpty ? 'Raf adı gerekli' : 'Bu raf zaten var');
            return;
          }
          if (lengthCm < 1) {
            setState(() => error = 'Uzunluk en az 1 cm olmalı');
            return;
          }
          final ok = shelf == null
              ? await controller.addShelf(
                  name: name,
                  lengthCm: lengthCm,
                  location: locationCtrl.text,
                )
              : await controller.updateShelf(
                  id: shelf.id,
                  name: name,
                  lengthCm: lengthCm,
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
                    helperText:
                        'Kitapların raf kaydı bu adla yapılır; '
                        'ad birebir aynı olmalı',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Kitaplardaki raf adları',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final name in suggestions)
                        ActionChip(
                          key: ValueKey('shelf-name-suggest-$name'),
                          label: Text(name),
                          tooltip: 'Raf adını "$name" yap',
                          onPressed: () => nameCtrl.text = name,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: lengthCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Uzunluk (cm)',
                    hintText: 'örn. 100',
                    helperText:
                        'Rafın kitapların dizildiği boşluk; 420 sayfalık '
                        'kitap ≈ 3 cm yer kaplar',
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

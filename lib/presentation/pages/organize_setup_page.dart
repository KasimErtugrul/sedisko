import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/services/organize_criterion.dart';
import '../controllers/shelf_organize_controller.dart';
import '../routes/app_routes.dart';
import '../widgets/organize/capacity_bar.dart';

/// Otomatik düzenleme kurulumu:
/// 1. Raf hazırlığı özeti (kapasite yetiyor mu?) + düzenleyiciye gidiş,
/// 2. Kriter seçimi (yazar / yayınevi / kitap adı / sayfa sayısı),
/// 3. "Kitaplarımın tamamını girdim" onayı — kullanıcı isteği: düzenleme
///    yalnız eksiksiz kitaplıkta başlar,
/// 4. "Hedef düzeni oluştur" → önizleme sayfası.
class OrganizeSetupPage extends StatefulWidget {
  const OrganizeSetupPage({super.key});

  @override
  State<OrganizeSetupPage> createState() => _OrganizeSetupPageState();
}

class _OrganizeSetupPageState extends State<OrganizeSetupPage> {
  ShelfOrganizeController get controller =>
      Get.find<ShelfOrganizeController>();

  final confirmed = false.obs;
  final criterion = Rxn<OrganizeCriterion>();

  @override
  void initState() {
    super.initState();
    // Raflar tanımsızsa kitaplardaki raf adlarını varsayılan kapasiteyle
    // içe aktar; kullanıcı sonra kapasiteleri düzeltir.
    controller.importExistingShelvesIfEmpty();
  }

  @override
  void dispose() {
    confirmed.close();
    criterion.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rafları otomatik düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _shelfReadinessCard(context),
          const SizedBox(height: 12),
          _criterionCard(context),
          const SizedBox(height: 12),
          _confirmationCard(context),
          const SizedBox(height: 16),
          Obx(() {
            final ready = controller.shelves.isNotEmpty &&
                criterion.value != null &&
                confirmed.value;
            return FilledButton.icon(
              key: const ValueKey('organize-create-arrangement'),
              onPressed: ready
                  ? () {
                      controller.buildPreview(criterion.value!);
                      Get.toNamed(Routes.organizePreview);
                    }
                  : null,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Hedef düzeni oluştur'),
            );
          }),
        ],
      ),
    );
  }

  Widget _shelfReadinessCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final shelvesEmpty = controller.shelves.isEmpty;
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shelves),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shelvesEmpty
                          ? 'Önce raflarını tanımla'
                          : 'Rafların hazır',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('organize-open-editor'),
                    tooltip: 'Rafları düzenle',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Get.toNamed(Routes.shelfEditor),
                  ),
                ],
              ),
              if (shelvesEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Kitaplığını gerçek raflarına bölmek için önce rafları '
                  'ekle: ad, kapasite ve yer (kat/oda).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...[
                const SizedBox(height: 8),
                CapacityBar(
                  count: controller.bookCount,
                  capacity: controller.totalCapacity,
                ),
                if (controller.needsMoreCapacity) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 18, color: scheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Kapasite yetmiyor: ${controller.bookCount - controller.totalCapacity} '
                          'kitap "Karışık kitaplar" rafına gitmek zorunda. '
                          'Yeni raf eklersen plan hepsine yer bulur.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _criterionCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kitaplar nasıl dağıtılsın?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final value in OrganizeCriterion.values)
              Obx(() => RadioListTile<OrganizeCriterion>(
                    key: ValueKey('criterion-${value.name}'),
                    contentPadding: EdgeInsets.zero,
                    value: value,
                    groupValue: criterion.value,
                    onChanged: (selected) =>
                        criterion.value = selected,
                    title: Text(value.label),
                    subtitle: Text(
                      value.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _confirmationCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Obx(() => CheckboxListTile(
              key: const ValueKey('organize-confirm-all-books'),
              controlAffinity: ListTileControlAffinity.leading,
              value: confirmed.value,
              onChanged: (value) => confirmed.value = value ?? false,
              title: const Text('Kitaplarımın tamamını girdim'),
              subtitle: Text(
                'Düzen, elindeki tüm kitaplara göre hesaplanır. Sonra '
                'ekleyeceğin kitaplar "yeni gelenler" olarak bekler; '
                '"Yeniden planla" ile yerleşirler.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )),
      ),
    );
  }
}

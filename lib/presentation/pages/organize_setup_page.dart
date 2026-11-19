import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/services/book_thickness.dart';
import '../../domain/services/organize_criterion.dart';
import '../controllers/shelf_organize_controller.dart';
import '../routes/app_routes.dart';
import '../widgets/organize/capacity_bar.dart';

/// Otomatik düzenleme kurulumu:
/// 1. **Favoriler** — kullanıcı isteği (1.15.0): asistan ÖNCE favori rafı
///    ve favori yazarları sorar; favori yazarların kitapları favori
///    rafa konur, kullanıcı önizlemede orada görür,
/// 2. Rafların hazırlığı (kalınlık modunda kapasite birim cinsinden),
/// 3. Kalınlık hesabı: kalın kitaplar daha çok yer kaplar (sayfa sayısı
///    → birim; ≈350 sayfa = 1 birim),
/// 4. Kriter seçimi (yazar / yayınevi / kitap adı / sayfa sayısı),
/// 5. "Kitaplarımın tamamını girdim" onayı — düzenleme yalnız eksiksiz
///    kitaplıkta başlar,
/// 6. "Hedef düzeni oluştur" → önizleme sayfası.
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
  final authorField = TextEditingController();

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
    authorField.dispose();
    super.dispose();
  }

  Future<void> _addAuthorFromField() async {
    final added = await controller.addFavoriteAuthor(authorField.text);
    if (added) authorField.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rafları otomatik düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _favoritesCard(context),
          const SizedBox(height: 12),
          _shelfReadinessCard(context),
          const SizedBox(height: 12),
          _thicknessCard(context),
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

  // ---------- Favoriler (önce sorulur) ----------

  Widget _favoritesCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final favorite = controller.effectiveFavoriteShelf;
          final shelves = controller.shelves;
          final suggestions = controller.favoriteAuthorSuggestions();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.star,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text('Favoriler', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Favori yazarlarının kitapları favori rafına konur; '
                'raf yalnızca onların kitaplarını tutar. Favori rafa '
                'sığmayan favori yazar bölünmez: kitapları bütün '
                'halinde başka bir rafa konur. Kalan kitaplar seçtiğin '
                'kritere göre dağılır.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text('Favori raf', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              if (shelves.isEmpty)
                Text(
                  'Raf tanımlayınca burada seçebilirsin.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('favorite-shelf-none'),
                      label: const Text('Yok'),
                      selected: favorite == null,
                      onSelected: (_) => controller.setFavoriteShelf(null),
                    ),
                    for (final shelf in shelves)
                      ChoiceChip(
                        key: ValueKey('favorite-shelf-${shelf.id}'),
                        label: Text('${shelf.name} (${shelf.capacity})'),
                        selected: favorite?.id == shelf.id,
                        onSelected: (_) => controller.setFavoriteShelf(shelf.id),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                'Favori yazarlar',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              if (controller.favoriteAuthors.isEmpty)
                Text(
                  'Henüz favori yazar seçmedin; istersen boş bırak.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final author in controller.favoriteAuthors)
                      InputChip(
                        key: ValueKey('favorite-author-chip-$author'),
                        label: Text(author),
                        onDeleted: () =>
                            controller.removeFavoriteAuthor(author),
                      ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('favorite-author-input'),
                      controller: authorField,
                      decoration: const InputDecoration(
                        hintText: 'Yazar adı yaz',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addAuthorFromField(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: const ValueKey('favorite-author-add'),
                    tooltip: 'Favori yazar ekle',
                    icon: const Icon(Icons.add),
                    onPressed: _addAuthorFromField,
                  ),
                ],
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Kitaplarındaki yazarlar',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final author in suggestions)
                      ActionChip(
                        key: ValueKey('favorite-suggest-$author'),
                        label: Text(author),
                        onPressed: () => controller.addFavoriteAuthor(author),
                      ),
                  ],
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  // ---------- Rafların hazırlığı ----------

  Widget _shelfReadinessCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final shelvesEmpty = controller.shelves.isEmpty;
      final thickness = controller.thicknessAware.value;
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
                if (thickness)
                  CapacityBar(
                    count: controller.totalBookHalfUnits,
                    capacity: controller.totalCapacityHalfUnits,
                    valueText: controller.totalOccupancyText(),
                  )
                else
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
                          thickness
                              ? 'Yer yetmiyor: ${BookThickness.formatHalf(controller.overflowHalfUnits)} '
                                  'birim eksik. Taşan kitaplar "Karışık '
                                  'kitaplar" rafına gitmek zorunda. Yeni '
                                  'raf eklersen plan hepsine yer bulur.'
                              : 'Kapasite yetmiyor: ${controller.bookCount - controller.totalCapacity} '
                                  'kitap "Karışık kitaplar" rafına gitmek '
                                  'zorunda. Yeni raf eklersen plan '
                                  'hepsine yer bulur.',
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

  // ---------- Kalınlık hesabı ----------

  Widget _thicknessCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Obx(() => SwitchListTile(
              key: const ValueKey('organize-thickness-switch'),
              value: controller.thicknessAware.value,
              onChanged: controller.setThicknessAware,
              title: const Text('Kalın kitaplar daha çok yer kaplar'),
              subtitle: Text(
                'Sayfa sayısı yere çevrilir: ≈350 sayfa = 1 birim '
                '(ör. 525 sayfalık kitap 1,5 birim). Kapalıysa kapasite '
                'yalnız kitap sayısıdır.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )),
      ),
    );
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

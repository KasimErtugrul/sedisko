import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/book_model.dart';
import '../../data/models/shelf_model.dart';
import '../../domain/services/book_thickness.dart';
import '../../domain/services/shelf_planner.dart';
import '../controllers/shelf_organize_controller.dart';
import '../routes/app_routes.dart';
import '../widgets/organize/capacity_bar.dart';

/// Hedef düzenin önizlemesi: raf raf, hangi kitaplar nerede olacak.
///
/// Bu sayfa HİÇBİR ŞEY YAZMAZ; kullanıcı "Taşıma planını oluştur" düğmesine
/// basana kadar kitapların raf ataması değişmez. Uyarılar (taşan grup,
/// kapasite yetersizliği) en üstte turuncu bandla gösterilir.
/// Favori raf (1.15.0) yıldız rozetiyle işaretlenir: kullanıcının
/// "favori rafıma favori yazarlarımı görebilsem" isteği burada karşılık
/// bulur — favori yazarların kitapları işaretli rafta listelenir.
class OrganizePreviewPage extends StatelessWidget {
  const OrganizePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ShelfOrganizeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Hedef düzen (önizleme)')),
      body: Obx(() {
        final arrangement = controller.preview.value;
        if (arrangement == null) {
          return const Center(child: Text('Önizleme yok. Kuruluma dön.'));
        }
        final favoriteShelfId =
            controller.previewOptions.value?.favoriteShelfId;

        return Column(
          children: [
            if (arrangement.warnings.isNotEmpty)
              _WarningsBanner(warnings: arrangement.warnings),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: [
                  _SummaryCard(summary: controller.previewMoveSummary()),
                  const SizedBox(height: 8),
                  for (final planned in arrangement.shelves)
                    _PlannedShelfCard(
                      key: ValueKey('planned-${planned.shelf.name}'),
                      planned: planned,
                      isFavorite: planned.shelf.id == favoriteShelfId,
                    ),
                  if (arrangement.unplaced.isNotEmpty)
                    _UnplacedCard(books: arrangement.unplaced),
                  Text(
                    controller.previewOptions.value?.thicknessAware ?? false
                        ? 'Kitap sırası, rafta fiziksel diziliş sırasıdır. '
                            'Doluluk birim cinsindendir: ≈350 sayfa = 1 '
                            'birim; kalın kitaplar daha çok yer kaplar. '
                            'Beğenmediysen geri dönüp kriteri değiştirebilirsin.'
                        : 'Kitap sırası, rafta fiziksel diziliş sırasıdır. '
                            'Beğenmediysen geri dönüp kriteri değiştirebilirsin.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('organize-create-plan'),
                  onPressed: () => _createPlan(context, controller),
                  icon: const Icon(Icons.route),
                  label: const Text('Taşıma planını oluştur'),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _createPlan(
    BuildContext context,
    ShelfOrganizeController controller,
  ) async {
    await controller.createPlan();
    if (controller.plan.value == null) {
      Get.snackbar(
        'Taşınacak kitap yok',
        'Kitaplar zaten hedef düzende; plan üretilmedi.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.offNamed(Routes.organizePlan);
  }
}

/// Plan özeti (1.18.1): çıktıyı sayılarla açıklar. Kitaplık çoğunlukla
/// hedef düzendeysen plan DOĞRU olarak yalnız 1-2 kitap taşır; bu kart
/// o çıktının "hata değil" olduğunu tek bakışta gösterir.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ({int moved, int untouched})? summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = this.summary;
    if (summary == null) return const SizedBox.shrink();
    final text = summary.moved == 0
        ? 'Taşınacak kitap yok: ${summary.untouched} kitap zaten hedef '
            'düzeninde. Plan üretmek yerine kurulumdan kriteri '
            'değiştirebilirsin.'
        : '${summary.moved} kitap taşınacak, ${summary.untouched} kitap '
            'zaten hedef düzeninde.';
    return Card(
      key: const ValueKey('preview-summary'),
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              summary.moved == 0 ? Icons.check_circle_outline : Icons.route,
              size: 20,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningsBanner extends StatelessWidget {
  const _WarningsBanner({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final warning in warnings)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Tek rafın planı: başlık (ad + yer + doluluk) ve kitap listesi.
/// Favori rafsa yıldız rozeti taşır.
class _PlannedShelfCard extends StatelessWidget {
  const _PlannedShelfCard({
    super.key,
    required this.planned,
    this.isFavorite = false,
  });

  final PlannedShelf planned;

  /// Bu raf, kullanıcının favori rafı mı?
  final bool isFavorite;

  bool get _isMix =>
      planned.shelf.name == ShelfModel.mixShelfName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Anahtar üstteki _PlannedShelfCard'dadır; Card'a ikinci kez konursa
    // testler 'aynı anahtarlı iki widget' bulur.
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isMix
                      ? Icons.folder_special_outlined
                      : isFavorite
                          ? Icons.star
                          : Icons.shelves,
                  color: _isMix ? scheme.tertiary : scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isMix
                        ? '${planned.shelf.name} (plan üretti)'
                        : planned.shelf.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isFavorite)
                  Text(
                    'Favori raf',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                if (planned.shelf.location.isNotEmpty)
                  Flexible(
                    child: Text(
                      planned.shelf.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (planned.thicknessAware)
              CapacityBar(
                count: planned.usedHalfUnits,
                capacity: planned.capacityHalfUnits,
                dense: true,
                valueText:
                    '${BookThickness.formatHalf(planned.usedHalfUnits)}/'
                    '${BookThickness.formatHalf(planned.capacityHalfUnits)} birim',
              )
            else
              CapacityBar(
                count: planned.count,
                capacity: planned.shelf.capacity,
                dense: true,
              ),
            const Divider(height: 16),
            if (planned.books.isEmpty)
              Text(
                'Bu raf boş kalacak.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (var i = 0; i < planned.books.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          planned.books[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          planned.books[i].authorsText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _UnplacedCard extends StatelessWidget {
  const _UnplacedCard({required this.books});

  final List<BookModel> books;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('planned-unplaced'),
      margin: const EdgeInsets.only(bottom: 10),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.error),
                const SizedBox(width: 8),
                Text(
                  '${books.length} kitap hiçbir rafa sığmadı',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni raf ekleyip yeniden planla; bu kitaplar şimdilik '
              'mevcut yerlerinde kalacak.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}

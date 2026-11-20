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
/// alan yetersizliği) en üstte turuncu bandla gösterilir.
///
/// **1.19.0:** her raf kartının başında düzen sıra numarası vardır
/// (plan 1. raftan başlar); doluluk cm cinsindendir. Özet kartı ve alt
/// açıklama, planın RAF İÇİ dizilişi kapsamadığını açıkça söyler —
/// kullanıcının "yalnız 1 kitap taşınacak" çıktısını bozuk sanmasını
/// önler (kullanıcı kararı: rehber değil, net açıklama).
/// Favori raf yıldız rozetiyle işaretlenir: favori yazarların kitapları
/// işaretli rafta listelenir (yalnız "Yazara göre" düzeninde).
///
/// **1.24.0 (keşke 26):** liste içinde DEĞİŞENLER de işaretli —
/// başka raftan gelen kitabın satırında ok rozeti ve "Taşınıyor"
/// yazısı durur, kartın başında "Bu rafa N kitap taşınıyor, M kitap
/// zaten burada" özeti okunur. Yüzlerce adın içinde hangi kitabın
/// yer değiştirdiği artık tek bakışta seçilir. HİÇBİR ŞEY YAZMAZ
/// sözü aynen durur: bu sayfa yalnız gösterir.
class OrganizePreviewPage extends StatelessWidget {
  const OrganizePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ShelfOrganizeController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Plan önizlemesi')),
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
                  // Raf kartları fiziksel sıradadır; başındaki numara
                  // düzenin 1. raftan başladığını gösterir.
                  for (var i = 0; i < arrangement.shelves.length; i++)
                    _PlannedShelfCard(
                      key: ValueKey(
                        'planned-${arrangement.shelves[i].shelf.name}',
                      ),
                      orderNumber: i + 1,
                      planned: arrangement.shelves[i],
                      isFavorite:
                          arrangement.shelves[i].shelf.id == favoriteShelfId,
                    ),
                  if (arrangement.unplaced.isNotEmpty)
                    _UnplacedCard(books: arrangement.unplaced),
                  Text(
                    'Listedeki sıra, kitapların hedef raftaki plan '
                    'sırasıdır. Plan yalnız kitapların HANGİ rafta '
                    'olacağını kapsar; rafta A→Z gibi dizilme emri '
                    'üretmez. Beğenmediysen geri dönüp "neye göre" '
                    'seçimini değiştirebilirsin.',
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
        'Kitaplar zaten istediğin düzende; plan üretilmedi.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.offNamed(Routes.organizePlan);
  }
}

/// Plan özeti (1.18.1): çıktıyı sayılarla açıklar. Kitaplık çoğunlukla
/// hedef düzendeysen plan DOĞRU olarak yalnız 1-2 kitap taşır; bu kart
/// o çıktının "hata değil" olduğunu tek bakışta gösterir ve planın
/// kapsamını açıkça yazar (1.19.0).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ({int moved, int untouched})? summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = this.summary;
    if (summary == null) return const SizedBox.shrink();
    final text = summary.moved == 0
        ? 'Taşınacak kitap yok: ${summary.untouched} kitap zaten '
            'yerinde. Plan üretmek yerine kurulumdan "neye göre" '
            'seçimini değiştirebilirsin.'
        : '${summary.moved} kitap taşınacak, ${summary.untouched} kitap '
            'zaten yerinde.';
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
                '$text Raf içi diziliş (A→Z gibi) bu planın kapsamı '
                'dışıdır; plan yalnız raf atamalarını taşır.',
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

/// Tek rafın planı: sıra numarası + ad + yer + doluluk + kitap listesi.
/// Favori rafsa yıldız rozeti taşır.
class _PlannedShelfCard extends StatelessWidget {
  const _PlannedShelfCard({
    super.key,
    required this.orderNumber,
    required this.planned,
    this.isFavorite = false,
  });

  /// Bu rafın düzen sırası (1'den başlar).
  final int orderNumber;

  final PlannedShelf planned;

  /// Bu raf, kullanıcının favori rafı mı?
  final bool isFavorite;

  bool get _isMix =>
      planned.shelf.name == ShelfModel.mixShelfName;

  /// Keşke 26 (1.24.0): bu rafa BAŞKA raftan taşınacak kitap sayısı.
  /// Raf ataması ad bazlıdır (books_v1'deki serbest raf adı); kitabın
  /// mevcut raf adı bu rafın adından farklıysa taşınmıştır.
  int get movedInCount => planned.books.where(_isMovedIn).length;

  bool _isMovedIn(BookModel book) =>
      book.shelf.trim() != planned.shelf.name;

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
                    '$orderNumber. ${_isMix
                        ? '${planned.shelf.name} (plan üretti)'
                        : planned.shelf.name}',
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
            CapacityBar(
              count: planned.usedMm,
              capacity: planned.capacityMm,
              dense: true,
              valueText:
                  '${planned.count} kitap • '
                  '${BookThickness.formatMm(planned.usedMm)}/'
                  '${BookThickness.formatMm(planned.capacityMm)}',
            ),
            // Keşke 26 (1.24.0): raf başına taşınma özeti — kart
            // listesinde hangi kitapların yeni geleceği sayıyla bellidir.
            if (movedInCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  key: ValueKey('planned-moved-line-${planned.shelf.name}'),
                  'Bu rafa $movedInCount kitap taşınıyor, '
                  '${planned.books.length - movedInCount} kitap zaten '
                  'burada.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
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
                    key: ValueKey('preview-row-${planned.books[i].id}'),
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
                      // Keşke 26 (1.24.0): başka raftan gelen kitap
                      // ok rozetiyle işaretli; yerinde olan rozetsiz.
                      if (_isMovedIn(planned.books[i])) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Başka raftan taşınıyor',
                          child: Icon(
                            Icons.subdirectory_arrow_right,
                            size: 16,
                            color: scheme.tertiary,
                          ),
                        ),
                      ],
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

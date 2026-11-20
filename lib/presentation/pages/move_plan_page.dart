import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/organize_plan_model.dart';
import '../controllers/shelf_organize_controller.dart';

/// Taşıma planı: tur tur, emir emir fiziksel yürüyüş senaryosu.
///
/// - Her tur = tek yer (kat/oda); aynı yerdeki işler tek turda toplanır.
/// - Her emir ya "X rafından al" ya da "X rafına koy"dur; rafta önce
///   ALMA sonra KOYMA sırası korunur (rafa koyacak yer açılsın).
/// - "Yaptım" işareti: turda KONAN kitapların rafı anında güncellenir;
///   yarıda bırakılan plan "Yeniden planla" ile kalan işten yeniden
///   kurulur.
class MovePlanPage extends StatelessWidget {
  const MovePlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ShelfOrganizeController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taşıma planı'),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('plan-menu'),
            // Keşke 9 (1.21.0): üç nokta menüsü ekran okuyucuya adını
            // söylesin; görsel davranış aynen korunur.
            tooltip: 'Seçenekler',
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'replan',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh),
                  title: Text('Yeniden planla'),
                ),
              ),
              PopupMenuItem(
                value: 'cancel',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.close),
                  title: Text('Planı iptal et'),
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'replan') {
                await controller.replan();
              } else if (value == 'cancel') {
                await _cancelPlan(context, controller);
              }
            },
          ),
        ],
      ),
      body: Obx(() {
        final plan = controller.plan.value;
        if (plan == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Aktif plan yok.\nRaflar sekmesinden "Otomatik düzenle" ile '
                'yeni bir düzen oluşturabilirsin.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final outsiders = controller.planOutsiders;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _ProgressCard(plan: plan),
            const SizedBox(height: 8),
            _HintCard(),
            const SizedBox(height: 8),
            if (outsiders.isNotEmpty) ...[
              _OutsidersCard(count: outsiders.length),
              const SizedBox(height: 8),
            ] else ...[
              // Kapsama kartı (1.19.2): taşınmayan kitaplar "sonra eklenmiş"
              // DEĞİL, hedef raftalarındadır. "Toplam 1 kitap taşınacak"
              // çıktısının kendini açıklaması için (kullanıcı kararı:
              // dürüst çıktı).
              const _CoverageCard(),
              const SizedBox(height: 8),
            ],
            for (var i = 0; i < plan.turs.length; i++)
              _TurCard(index: i, tur: plan.turs[i], done: plan.completedTurIndexes.contains(i)),
          ],
        );
      }),
    );
  }

  Future<void> _cancelPlan(
    BuildContext context,
    ShelfOrganizeController controller,
  ) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Plan iptal edilsin mi?'),
        content: const Text(
          'Plan silinir; kitapların mevcut raf atamaları değişmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Devam et'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.cancelPlan();
    }
  }
}

/// İlerleme kartı: tamamlanan tur sayısı + taşınacak kitap sayısı.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.plan});

  final OrganizePlanModel plan;

  @override
  Widget build(BuildContext context) {
    final done = plan.completedCount;
    final total = plan.turs.length;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$done/$total tur tamam',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              key: const ValueKey('plan-progress'),
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              'Toplam ${plan.totalMoveCount} kitap taşınacak • '
              'kriter: ${plan.criterion.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Aynı yerdeki (kat) rafların işleri tek turda: bir rafta önce '
          'çıkan kitapları al, sonra gelenleri koy. Tek elde en fazla '
          '${ShelfOrganizeController.carryLimit} kitap; sığmayanlar '
          'aynı turun devamında gelir.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _OutsidersCard extends StatelessWidget {
  const _OutsidersCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('plan-outsiders'),
      margin: EdgeInsets.zero,
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '$count kitap plan yapıldıktan sonra eklendi; "Yeniden planla" '
          'dediğinde kalan işle birlikte yerleşirler.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}

/// Kapsama kartı (1.19.2): plan kitaplığın tamamını kapsıyor; dışarıda
/// kitap yok. Taşınmayanlar planın hedefinde zaten kendi raftalarında.
class _CoverageCard extends StatelessWidget {
  const _CoverageCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('plan-coverage'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Plan kitaplığın tamamını kapsıyor. Taşınmayan kitaplar '
          'planın hedefinde zaten kendi raftalarındadır; sonradan '
          'eklediğin kitaplar olursa "Yeniden planla" onları da '
          'yerleştirir.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

/// Tek tur kartı: yer başlığı + sıralı emirler + "Yaptım" düğmesi.
///
/// Büyük turda emirler sabit yükseklikte kaydırılabilir listede
/// gösterilir (1.18.1): 2000+ kitaplık tek turun yüzlerce emri
/// ExpansionTile içinde bir kerede kurulunca arayüz saniyelerce
/// kilitleniyordu; ListView.builder yalnız görünür emirleri kurar.
class _TurCard extends StatelessWidget {
  const _TurCard({
    required this.index,
    required this.tur,
    required this.done,
  });

  /// Bu sayıyı aşan turlarda emir listesi kaydırılabilir pencerede
  /// kurulur (tembel kurulum eşiği).
  static const int lazyActionThreshold = 24;

  final int index;
  final MoveTurModel tur;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('plan-tur-$index'),
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: !done,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(
          done ? Icons.check_circle : Icons.route,
          color: done
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          '${index + 1}. TUR — ${tur.location}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          done ? 'Tamamlandı • ${tur.moveCount} kitap' : '${tur.moveCount} kitap işi',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          if (tur.actions.length > lazyActionThreshold)
            SizedBox(
              height: 320,
              child: ListView.builder(
                key: ValueKey('tur-actions-lazy-$index'),
                itemCount: tur.actions.length,
                itemBuilder: (context, i) => _ActionTile(
                  step: i + 1,
                  action: tur.actions[i],
                  done: done,
                ),
              ),
            )
          else
            for (var i = 0; i < tur.actions.length; i++)
              _ActionTile(
                step: i + 1,
                action: tur.actions[i],
                done: done,
              ),
          if (!done)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: ValueKey('tur-done-$index'),
                  onPressed: () => _markDone(context),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Yaptım'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _markDone(BuildContext context) async {
    final controller = Get.find<ShelfOrganizeController>();
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('${index + 1}. tur tamamlandı mı?'),
        content: Text(
          'Bu turdaki ${tur.moveCount} kitabın raf ataması uygulamada '
          'güncellenecek. Fiziksel olarak yerleştirdiysen onayla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Hayır, daha değil'),
          ),
          FilledButton(
            key: const ValueKey('tur-done-confirm'),
            onPressed: () => Get.back(result: true),
            child: const Text('Yaptım'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final hadPlan = controller.plan.value != null;
    await controller.markTurDone(index);
    // Plan tamamlandıysa denetleyici planı temizledi; kullanıcıyı kutla.
    if (hadPlan && controller.plan.value == null && context.mounted) {
      Get.snackbar(
        'Düzenleme tamamlandı',
        'Tüm turlar tamam; kitaplar hedef düzende.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

/// Tek emir: "X rafından al" ya da "X rafına koy" + kitap başlıkları.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.step,
    required this.action,
    required this.done,
  });

  final int step;
  final MoveActionModel action;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shelfDisplay =
        action.shelf.trim().isEmpty ? 'Rafsız' : action.shelf.trim();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: action.isPickup
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : scheme.primaryContainer.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                action.isPickup ? Icons.output : Icons.input,
                size: 18,
                color: action.isPickup ? scheme.secondary : scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$step. ${action.isPickup
                          ? '$shelfDisplay rafından şu kitapları al'
                          : '$shelfDisplay rafına şu kitapları koy'} '
                  '(${action.moves.length} kitap)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final move in action.moves)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text(
                '• ${move.title.isEmpty ? "(adsız kitap)" : move.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: done
                    ? Theme.of(context).textTheme.bodySmall?.copyWith(
                        decoration: TextDecoration.lineThrough)
                    : Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

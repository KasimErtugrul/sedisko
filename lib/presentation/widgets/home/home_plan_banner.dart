import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shelf_organize_controller.dart';
import '../../routes/app_routes.dart';

/// Ana sayfanın "Taşıma planı sürüyor" hatırlatma kartı (1.22.0 — keşke 29).
///
/// Hasan'ın notu: "İlerleme kartı Raflar sekmesinde duruyor; ama ben Ana
/// Sayfa'da yaşıyorum. '2/5 tur tamam, devam edelim mi?' diye bir kart ana
/// sayfada olsaydı, planı yarım bırakıp unuturdum."
///
/// Kart YALNIZ plan sürerken kurulur; bütün turlar 'Yaptım' ile
/// işaretlenince ya da plan iptal edilince kaybolur (denetleyici planı
/// siler; kart da akıştan çekilir). Raflar sekmesindeki ilerleme kartıyla
/// aynı adları ve aynı yönlendirmeyi taşır; oradaki kart AYNEN durur —
/// iki giriş, tek hedef ([Routes.organizePlan]).
///
/// Denetleyici izole testlerde kayıtlı olmayabilir; kayıtlı değilken kart
/// hiç kurulmaz (bölümler gibi boş ipucuyla yer tutmaz: bu bir bölüm
/// değil, durum kartıdır).
class HomePlanBanner extends StatelessWidget {
  const HomePlanBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ShelfOrganizeController>()) {
      return const SizedBox.shrink();
    }
    return Obx(() {
      final plan = Get.find<ShelfOrganizeController>().plan.value;
      if (plan == null) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      return Card(
        key: const ValueKey('home-plan-banner'),
        margin: const EdgeInsets.only(bottom: 8),
        color: scheme.secondaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Get.toNamed(Routes.organizePlan),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.route, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taşıma planı sürüyor',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                      Text(
                        // Keşke 28 (1.24.0): "tur" yerine günlük kelime
                        // "gezi" (Raflar sekmesi kartıyla aynı ad).
                        '${plan.completedCount}/${plan.turs.length} gezi '
                        'tamam — devam etmek için dokun.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSecondaryContainer,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

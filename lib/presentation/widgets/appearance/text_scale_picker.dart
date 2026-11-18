import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_palette.dart';
import '../../controllers/settings_controller.dart';

/// Ayarlar > Görünüm: yazı boyutu seçici (4 kademe).
///
/// Kademeler [AppPalettes.textScales] ile aynıdır; seçim anında tüm
/// uygulamaya sirayet eder (GetMaterialApp > MediaQuery.textScaler).
/// Altındaki önizleme kartı seçilen kademenin nasıl görüneceğini
/// gösterir; önizleme bilinçli olarak MediaQuery'den bağımsız ölçeklenir
/// (ayarlarda ayarlar sayfası da zaten ölçeklenir, önizleme farkı net
/// göstermek için çarpan etiketiyle birlikte durur).
class TextScalePicker extends StatelessWidget {
  const TextScalePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    final options = const [
      (0.85, 'Küçük'),
      (1.0, 'Normal'),
      (1.15, 'Büyük'),
      (1.3, 'Çok büyük'),
    ];

    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (scale, label) in options)
                ChoiceChip(
                  key: ValueKey('text-scale-$scale'),
                  label: Text(label),
                  selected: controller.textScale.value == scale,
                  onSelected: (_) => controller.setTextScale(scale),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Önizleme • %${(controller.textScale.value * 100).round()}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Simyacı — okuduğun sayfa 50/200',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                    textScaler: TextScaler.linear(controller.textScale.value),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

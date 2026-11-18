import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_palette.dart';
import '../../controllers/settings_controller.dart';
import 'hue_color_picker.dart';

/// Ayarlar > Görünüm: renk paleti seçici.
///
/// Altı hazır palet + "Özel" yolunu swatch olarak gösterir. Hazır palet
/// seçimi anında temaya sirayet eder; "Özel" swatch'ı hue kaydırıcılı
/// [showHueColorPicker] diyaloğunu açar ve seçilen renk tohum (seed)
/// olarak tüm uygulamaya uygulanır.
class PalettePicker extends StatelessWidget {
  const PalettePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    return Obx(
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final palette in AppPalettes.presets)
            _PaletteSwatch(
              key: ValueKey('palette-${palette.id}'),
              color: palette.seed,
              label: palette.name,
              selected: controller.paletteId.value == palette.id,
              onTap: () => controller.setPalette(palette.id),
            ),
          _PaletteSwatch(
            key: const ValueKey('palette-custom'),
            color: controller.seedColor,
            label: 'Özel',
            selected: controller.paletteId.value == AppPalettes.customId,
            onTap: () => showHueColorPicker(
              context,
              initial: controller.seedColor,
              onPick: controller.setCustomSeed,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek swatch: renk noktası + ad; seçiliyken tohum rengiyle çerçeve.
class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            width: selected ? 2 : 1,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
          color: selected
              ? theme.colorScheme.primaryContainer.withAlpha(77)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 10, backgroundColor: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 14, color: theme.colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

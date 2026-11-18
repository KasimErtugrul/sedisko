import 'package:flutter/material.dart';

/// Kullanıcının kendi tohum rengini seçtiği diyalog: ton (hue) kaydırıcısı
/// + açıklık (lightness) kaydırıcısı + ton kareleri + canlı önizleme.
///
/// Yeni paket eklemez: renk HSL uzayında üretilir; doygunluk sabittir
/// (0.62) çünkü tohum rengi Material 3'e girip tonlara dağılır; aşırı
/// doygun/ışık renkleri şemayı bozar. "Seç" basılınca [onPick] ARGB int
/// döner (SettingsController saklar, paleti 'custom' yapar).
Future<void> showHueColorPicker(
  BuildContext context, {
  required Color initial,
  required ValueChanged<int> onPick,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => HueColorPickerDialog(
      initial: initial,
      onPick: onPick,
    ),
  );
}

class HueColorPickerDialog extends StatefulWidget {
  const HueColorPickerDialog({
    super.key,
    required this.initial,
    required this.onPick,
  });

  final Color initial;
  final ValueChanged<int> onPick;

  @override
  State<HueColorPickerDialog> createState() => _HueColorPickerDialogState();
}

class _HueColorPickerDialogState extends State<HueColorPickerDialog> {
  static const double _saturation = 0.62;

  late double _hue = _hueOf(widget.initial);
  late double _lightness = _lightnessOf(widget.initial);

  HSLColor get _current => HSLColor.fromAHSL(
        1.0,
        _hue,
        _saturation,
        _lightness,
      );

  static double _hueOf(Color color) =>
      HSLColor.fromColor(color).hue.roundToDouble();

  static double _lightnessOf(Color color) {
    final l = HSLColor.fromColor(color).lightness;
    // Kaydırıcı aralığına kırp: 0.30–0.85 dışı tohum olarak zayıftır.
    return l.clamp(0.30, 0.85).toDouble();
  }

  void _applyLightness(double value) =>
      setState(() => _lightness = value.clamp(0.30, 0.85).toDouble());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shades = [
      for (final l in const [0.85, 0.75, 0.65, 0.55, 0.45, 0.35])
        HSLColor.fromAHSL(1.0, _hue, _saturation, l).toColor(),
    ];

    return AlertDialog(
      title: const Text('Özel renk'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Canlı önizleme: şemada bu renk nasıl görünür?
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: _current.toColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                'Kitaplığım',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: _lightness > 0.62
                      ? Colors.black87
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Ton', style: theme.textTheme.labelMedium),
            Slider(
              key: const ValueKey('hue-slider'),
              value: _hue,
              min: 0,
              max: 360,
              divisions: 360,
              label: '${_hue.round()}°',
              onChanged: (v) => setState(() => _hue = v),
            ),
            Text('Açıklık', style: theme.textTheme.labelMedium),
            Slider(
              key: const ValueKey('lightness-slider'),
              value: _lightness,
              min: 0.30,
              max: 0.85,
              divisions: 55,
              label: '${(_lightness * 100).round()}',
              onChanged: _applyLightness,
            ),
            // Ton kareleri: kaydırıcıya dokunmadan hızlı açıklık seçimi.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final shade in shades)
                  GestureDetector(
                    onTap: () {
                      final l =
                          HSLColor.fromColor(shade).lightness;
                      _applyLightness(l);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: shade,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('pick-color-confirm'),
          onPressed: () {
            // Tohum rengini düzleştirilmiş (flat) ARGB int olarak ver;
            // geçerli aralık 0..0xFFFFFFFF'tir.
            widget.onPick(_current.toColor().value | 0xFF000000);
            Navigator.of(context).pop();
          },
          child: const Text('Seç'),
        ),
      ],
    );
  }
}

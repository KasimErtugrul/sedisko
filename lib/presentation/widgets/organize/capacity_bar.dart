import 'package:flutter/material.dart';

/// Doluluk çubuğu: göstergesi + lineer ilerleme.
///
/// Raf kartları, hedef düzen önizlemesi ve taşıma planı bu tek widget'ı
/// paylaşır; taşan (count > capacity) durumlarda çubuk kırmızıya döner ki
/// kullanıcı kapasite aşımını tek bakışta görsün.
///
/// 1.19.0 cm modelinde count/capacity milimetre cinsinden geçirilir ve
/// `valueText` hazır metin gelir (ör. '38 kitap • 96,4/125 cm'); oran
/// değişmez. valueText null ise 'count/capacity' yazılır.
class CapacityBar extends StatelessWidget {
  const CapacityBar({
    super.key,
    required this.count,
    required this.capacity,
    this.dense = false,
    this.valueText,
  });

  final int count;
  final int capacity;

  /// true: kart içi kompakt görünüm (küçük yazı, ince çubuk).
  final bool dense;

  /// Göstergede count/capacity yerine gösterilecek hazır metin
  /// (ör. '38 kitap • 96,4/125 cm'); null ise 'count/capacity' yazılır.
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overflowing = capacity > 0 && count > capacity;
    final ratio =
        capacity > 0 ? (count / capacity).clamp(0.0, 1.0).toDouble() : 0.0;
    final color = overflowing
        ? scheme.error
        : count == capacity ? scheme.primary : scheme.primaryContainer;

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: dense ? 6 : 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        SizedBox(width: dense ? 8 : 12),
        Flexible(
          child: Text(
            valueText ?? '$count/$capacity',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: dense
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

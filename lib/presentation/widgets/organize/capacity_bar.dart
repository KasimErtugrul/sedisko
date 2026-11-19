import 'package:flutter/material.dart';

/// Doluluk çubuğu: '12/50' göstergesi + lineer ilerleme.
///
/// Raf kartları, hedef düzen önizlemesi ve taşıma planı bu tek widget'ı
/// paylaşır; taşan (count > capacity) durumlarda çubuk kırmızıya döner ki
/// kullanıcı kapasite aşımını tek bakışta görsün.
class CapacityBar extends StatelessWidget {
  const CapacityBar({
    super.key,
    required this.count,
    required this.capacity,
    this.dense = false,
  });

  final int count;
  final int capacity;

  /// true: kart içi kompakt görünüm (küçük yazı, ince çubuk).
  final bool dense;

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
        Text(
          '$count/$capacity',
          style: dense
              ? Theme.of(context).textTheme.bodySmall
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

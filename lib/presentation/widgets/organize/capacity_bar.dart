import 'package:flutter/material.dart';

/// Doluluk çubuğu: '12/50' göstergesi + lineer ilerleme.
///
/// Raf kartları, hedef düzen önizlemesi ve taşıma planı bu tek widget'ı
/// paylaşır; taşan (count > capacity) durumlarda çubuk kırmızıya döner ki
/// kullanıcı kapasite aşımını tek bakışta görsün.
///
/// Kalınlık modunda (1.15.0) göstergenin yerine birim metni konur:
/// arayan taraf `valueText` ile '26,5/40 birim' gibi bir metin verir ve
/// count/capacity'ye yarım-birim değerlerini geçirir (oran değişmez).
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
  /// (ör. '26,5/40 birim'); null ise 'count/capacity' yazılır.
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

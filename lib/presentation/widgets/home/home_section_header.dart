import 'package:flutter/material.dart';

/// Ana sayfa bölüm başlığı; istenirse sağda "Tümü" aksiyonu gösterir.
///
/// Baseline hizalı Row yerine tek [Text] kullanılır: uzun başlıklar
/// sınırlı genişlikte sarılır, taşma yapmaz.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  }) : assert(
          (onAction == null) == (actionLabel == null),
          'Aksiyon etiketi ve aksiyonu birlikte verin ya da hiç vermeyin.',
        );

  final String title;

  /// Sağdaki aksiyon etiketi (ör. "Tümü"); [onAction] ile birlikte verilir.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Aksiyonun test anahtarı (ör. ValueKey('see-all-authors')).
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (onAction != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Boş bölümün yönlendirme ipucu kartı (ör. favori yokken Favoriler).
class HomeSectionEmptyHint extends StatelessWidget {
  const HomeSectionEmptyHint({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.favorite_outline,
              size: 22,
              color: scheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

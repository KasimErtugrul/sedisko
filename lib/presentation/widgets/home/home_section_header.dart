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

/// Boş bölümün ipucu kartı: bölüm veri içermese de bölüm gizlenmez,
/// yerinde kısa bir "Henüz ..." metni gösterilir (ör. favori yokken
/// Favoriler). [icon], bölümün konusuna uyan bir sembol seçilir.
///
/// Keşke 4 (1.23.0): yönlendirme yazı değil basılabilir düğme olabilir —
/// "Raflar sekmesinden raf ekleyebilirsin" yazısına dokununca Raflar
/// sekmesi açılır ([actionLabel]/[onAction] verilirse; açıklama dokunuşu
/// kalır, bölüm her koşulda aynı yerde durur).
class HomeSectionEmptyHint extends StatelessWidget {
  const HomeSectionEmptyHint({
    super.key,
    required this.message,
    this.icon = Icons.favorite_outline,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  }) : assert(
          (onAction == null) == (actionLabel == null),
          'Aksiyon etiketi ve aksiyonu birlikte verin ya da hiç vermeyin.',
        );

  final String message;

  /// Kart başındaki sembol; bölüm konusuna göre değişir
  /// (okuma için kitap, hedef için bayrak vb.).
  final IconData? icon;

  /// İpucun gösterdiği yerde açılan düğmenin etiketi (ör.
  /// "Raflar sekmesine git"); [onAction] ile birlikte verilir.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Aksiyonun test anahtarı.
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 22,
                color: scheme.outline,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (onAction != null)
                    TextButton(
                      key: actionKey,
                      onPressed: onAction,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(actionLabel!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

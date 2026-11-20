import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/platform_support.dart';
import '../../controllers/settings_controller.dart';

/// Kitaplık tamamen boşken ana sayfanın yönlendirici boş durumu.
///
/// Keşke 3 (1.23.0): "İlk kitabını barkod tarayarak ekle" yazısı, barkod
/// düğmesi o cihazda yokken ya da ayar kapatılmışken de duruyordu
/// ("Yazıyı okudum, barkod düğmesini aradım; düğme yoktu"). Metin artık
/// barkod kullanılabilirliğini izler: tarama yokken "elle ekle" der.
///
/// Keşke 4 (1.23.0): yönlendirme yazı değil, basılabilir düğmedir —
/// "Bana bir yeri söylüyorsanız, o yere götüren düğmeyi de koyun".
/// Düğme FAB'ın açtığı ekle menüsünü açar ve aynı adı taşır: aynı iş,
/// aynı ad (keşke 21'in dersi).
///
/// Keşke 2 (1.26.0): boş kitaplıkta ikinci yol da görünür — 'Nasıl
/// kullanılır?' düğmesi yardım sayfasını açar (Hasan'ın ilk deneyimi:
/// "Takıldığım her yerde deneme yanılma ile ilerledim").
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.hasBooks,
    this.onAdd,
    this.onHelp,
  });

  final bool hasBooks;

  /// Boş kitaplıkta "Kitap ekle" düğmesinin aksiyonu (FAB'ın açtığı
  /// menünün aynısı). Verilmezse düğme çizilmez (arama boşluğunda
  /// ek eylem gerekmez; arama alanı hemen üsttedir).
  final VoidCallback? onAdd;

  /// Boş kitaplıkta 'Nasıl kullanılır?' düğmesinin aksiyonu (keşke 2,
  /// 1.26.0). Arama boşluğunda çizilmez.
  final VoidCallback? onHelp;

  /// Barkod kullanılabiliyorsa orijinal vaat aynen durur; yoksa dürüst
  /// alternatif gösterilir. Denetleyici kayıtlıyken tercihe abone olur:
  /// Ayarlar'da anahtar kapatılıp ana sayfaya dönüldüğünde metin taze
  /// yazılır (IndexedStack'te sayfa yeniden kurulmasa bile).
  ///
  /// Dikkat (Obx sözleşmesi): yalnızca EN AZ BİR observable kesin okunacaksa
  /// Obx kurulur. Platform desteği sabittir — onu Obx'in dışında ele almak,
  /// '&&' kısa devresi observable okunmadan çıkmışsa "improper use of GetX"
  /// hatasını önler.
  Widget _message() {
    const scanText = 'Kitaplığın boş.\nİlk kitabını barkod tarayarak ekle.';
    const manualText = 'Kitaplığın boş.\nİlk kitabını elle ekleyebilirsin.';
    if (!PlatformSupport.supportsBarcodeScan) {
      return const Text(manualText, textAlign: TextAlign.center);
    }
    if (!Get.isRegistered<SettingsController>()) {
      return const Text(scanText, textAlign: TextAlign.center);
    }
    return Obx(() {
      final scan = Get.find<SettingsController>().showScanActions.value;
      return Text(
        scan ? scanText : manualText,
        textAlign: TextAlign.center,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasBooks ? Icons.search_off : Icons.library_books_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            hasBooks
                ? const Text(
                    'Aramana uyan kitap yok.',
                    textAlign: TextAlign.center,
                  )
                : _message(),
            if (hasBooks) ...[
              const SizedBox(height: 12),
              Text(
                'Durum çipleriyle daraltabilirsin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!hasBooks && onAdd != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('empty-add-book'),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Kitap ekle'),
              ),
            ],
            // Keşke 2 (1.26.0): ikinci yol — yardım sayfası.
            if (!hasBooks && onHelp != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('empty-open-help'),
                onPressed: onHelp,
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Nasıl kullanılır?'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

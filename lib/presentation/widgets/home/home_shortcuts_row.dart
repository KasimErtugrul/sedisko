import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../routes/route_args.dart';

/// Ana sayfanın "Kısayollar" satırı (1.22.0 — keşke 13, 14).
///
/// Hasan'ın notları: "Kitap listesini beş dakika aradım; komşuya sormak
/// üzereydim" (keşke 13) ve "Alt barda dört sekme var; ödünç verilenler,
/// ödünç aldıklarım ve satın alınacaklar sayfaları hiçbirinde yok; bölüm
/// başlığındaki minik 'Tümü' yazısı gözüme görünmedi bile" (keşke 14).
///
/// Çözüm: en sık aranan dört hedef, ana sayfada her koşulda duran YAZILI
/// düğmelerle açılır. 'Tüm kitaplar' hedefi Raflar sekmesindeki kartın,
/// öbür üçü bölüm başlıklarındaki 'Tümü' aksiyonlarının aynısıdır — bir
/// yerin adı her yerde aynıdır (keşke 21'in dersi: iki ad, karışma demek).
/// Listenin kendisi ana sayfaya gelmez (1.16.0 kararı durur); kapısı gelir.
///
/// Satır bir bölüm DEĞİLDİR: kitaplık durumuna bağlı olmadığı için her
/// koşulda aynı yerde durur; düzen oynamaz. [Wrap] kullanılır: dar ekranda
/// (360 dp, 1.3 metin ölçeği) çipler alt satıra sarılır, taşma yapmaz.
class HomeShortcutsRow extends StatelessWidget {
  const HomeShortcutsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const ValueKey('home-shortcuts'),
      spacing: 8,
      runSpacing: 8,
      children: [
        _shortcut(
          key: 'home-shortcut-all-books',
          icon: Icons.auto_stories,
          label: 'Tüm kitaplar',
          onTap: () => Get.toNamed(Routes.shelf, arguments: const ShelfArgs()),
        ),
        _shortcut(
          key: 'home-shortcut-loans',
          icon: Icons.book_outlined,
          label: 'Ödünç verilenler',
          onTap: () => Get.toNamed(Routes.loans),
        ),
        _shortcut(
          key: 'home-shortcut-borrowed',
          icon: Icons.swap_horiz_outlined,
          label: 'Ödünç aldıkların',
          onTap: () => Get.toNamed(Routes.borrowed),
        ),
        _shortcut(
          key: 'home-shortcut-wishlist',
          icon: Icons.shopping_cart_outlined,
          label: 'Satın alınacaklar',
          onTap: () => Get.toNamed(Routes.wishlist),
        ),
      ],
    );
  }

  Widget _shortcut({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      key: ValueKey(key),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

import 'package:flutter/material.dart';

import '../widgets/responsive/app_breakpoints.dart';
import 'authors_page.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'shelves_page.dart';

/// Ana kabuk: 'Ana Sayfa', 'Raflar', 'Yazarlar' ve 'Ayarlar' sekmeleri.
///
/// Responsive kuralı: dar ekranda (telefon) alt [NavigationBar]; geniş
/// ekranda (tablet / yatay / masaüstü penceresi, >= 600 dp) sol
/// [NavigationRail]. İki gösterim de aynı sekmeleri ve aynı [IndexedStack]
/// durumunu kullanır: sekme değişince kitaplık yeniden yüklenmez, arama
/// alanı temizlenmez.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  /// Sekme tarifi: (çubuk ikonu, seçili ikon, etiket). Alt bar ve rail
  /// aynı listeyi kullanır; gösterimler arasında sekme bütünlüğü korunur.
  static const List<(IconData, IconData, String)> _destinations = [
    (Icons.home_outlined, Icons.home, 'Ana Sayfa'),
    (Icons.shelves, Icons.shelves, 'Raflar'),
    (Icons.people_outline, Icons.people, 'Yazarlar'),
    (Icons.settings_outlined, Icons.settings, 'Ayarlar'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = AppBreakpoints.isWide(constraints.maxWidth);
        final stack = _pageStack();
        return Scaffold(
          body: wide
              ? Row(
                  children: [
                    _rail(),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: stack),
                  ],
                )
              : stack,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2),
                        label: d.$3,
                      ),
                  ],
                ),
        );
      },
    );
  }

  /// Sekme içerikleri; dar ve geniş gösterimde aynı ağaç kullanılır.
  Widget _pageStack() {
    return IndexedStack(
      index: _index,
      children: [
        // Ana sayfadaki "Rafların" ve "En çok kitaba sahip yazarlar"
        // bölümlerinin "Tümü" aksiyonları ilgili sekmeye geçirir.
        HomePage(
          onOpenShelves: () => setState(() => _index = 1),
          onOpenAuthors: () => setState(() => _index = 2),
        ),
        const ShelvesPage(),
        const AuthorsPage(),
        const SettingsPage(),
      ],
    );
  }

  /// Geniş ekran rail'i; ana sayfa içeriği Expanded ile yanında akar.
  Widget _rail() {
    return NavigationRail(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      labelType: NavigationRailLabelType.all,
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.$1),
            selectedIcon: Icon(d.$2),
            label: Text(d.$3),
          ),
      ],
    );
  }
}

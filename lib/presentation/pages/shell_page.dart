import 'package:flutter/material.dart';

import 'authors_page.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'shelves_page.dart';

/// Alt navigasyonlu ana kabuk: 'Ana Sayfa', 'Raflar', 'Yazarlar' ve
/// 'Ayarlar' sekmeleri.
///
/// [IndexedStack] tüm sekmelerin durumunu korur; sekme değişince kitaplık
/// yeniden yüklenmez ve arama alanı temizlenmez.
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
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
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.shelves),
            selectedIcon: Icon(Icons.shelves),
            label: 'Raflar',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Yazarlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}

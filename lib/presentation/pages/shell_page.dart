import 'package:flutter/material.dart';

import 'settings_page.dart';
import 'shelves_page.dart';

/// Alt navigasyonlu ana kabuk: 'Raflar' ve 'Ayarlar' sekmeleri.
///
/// [IndexedStack] her iki sekmenin durumunu korur; sekme değişince kitaplık
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
        children: const [ShelvesPage(), SettingsPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shelves),
            selectedIcon: Icon(Icons.shelves),
            label: 'Raflar',
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

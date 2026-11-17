import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../widgets/book_tile.dart';
import '../widgets/status_filter_row.dart';
import '../controllers/library_controller.dart';

/// 'Raflar' sekmesi: yatay raf kartları ve arama.
///
/// - Arama boşken: 'Tüm kitaplar' ve raflar, ad + kitap sayısı gösteren
///   yatay kaydırılabilir kartlar halinde. Karta dokununca o rafın kitapları
///   ayrı bir sayfada açılır ([Routes.shelf]).
/// - Arama yazılırken: durum filtresi + eşleşen kitap listesi.
///
/// Liste [ListView.builder] ile kurulur; 20+ raf / 200+ kitap kütüphanelerinde
/// yalnız görünür öğeler inşa edilir.
class ShelvesPage extends GetView<LibraryController> {
  const ShelvesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitaplığım')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: _buildSearchField(),
              ),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (controller.books.isEmpty) {
                    return const _EmptyState(hasBooks: false);
                  }
                  final searching = controller.query.value.trim().isNotEmpty;
                  return searching ? _searchResults() : _shelfStrip(context);
                }),
              ),
            ],
          ),
          Obx(
            () => controller.isLookingUp.value
                ? Container(
                    color: Colors.black38,
                    alignment: Alignment.center,
                    child: const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text("Open Library'de aranıyor..."),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Kitap ekle'),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: controller.searchCtrl,
      onChanged: (v) => controller.query.value = v,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Kitap, yazar, raf veya ISBN ara',
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Obx(
          () => controller.query.value.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Aramayı temizle',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.searchCtrl.clear();
                    controller.query.value = '';
                  },
                ),
        ),
      ),
    );
  }

  /// Yatay raf kartları: 'Tüm kitaplar' + dolu raflar + varsa 'Rafsız'.
  Widget _shelfStrip(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: controller.shelfKeys.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ShelfCard(
                  key: const ValueKey('shelf-card-all'),
                  icon: Icons.auto_stories,
                  name: 'Tüm kitaplar',
                  count: controller.books.length,
                  onTap: () =>
                      Get.toNamed(Routes.shelf, arguments: const ShelfArgs()),
                );
              }
              final key = controller.shelfKeys[index - 1];
              return _ShelfCard(
                key: ValueKey('shelf-card-$key'),
                icon: key == 'Rafsız' ? Icons.folder_off_outlined : Icons.shelves,
                name: key,
                count: controller.shelfCount(key),
                onTap: () => Get.toNamed(
                  Routes.shelf,
                  arguments: ShelfArgs(shelf: key),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          child: Text(
            'Bir rafa dokunarak o raftaki kitapları açabilirsin.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// Arama yazılırken durum filtresi + sonuç listesi gösterilir.
  Widget _searchResults() {
    final items = controller.filteredBooks();
    return Column(
      children: [
        const StatusFilterRow(),
        Expanded(
          child: items.isEmpty
              ? const _EmptyState(hasBooks: true)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final book = items[index];
                    return BookTile(
                      key: ValueKey(book.id),
                      book: book,
                      onTap: () =>
                          Get.toNamed(Routes.detail, arguments: book.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddSheet(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Platform desteği ve kullanıcı tercihi birlikte ele alınır.
            if (SettingsController.scanActionsVisible)
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Barkod tara'),
                subtitle:
                    const Text('ISBN ile Open Library\'den bilgileri getir'),
                onTap: () {
                  Get.back();
                  controller.addByScan();
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Manuel ekle'),
              subtitle: const Text('Bilgileri kendin gir'),
              onTap: () {
                Get.back();
                Get.toNamed(Routes.form, arguments: const BookFormArgs());
              },
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }
}

/// Yatay raf kartı: raf adı + kitap sayısı.
class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    super.key,
    required this.icon,
    required this.name,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String name;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 148,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: scheme.primary),
                const Spacer(),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count kitap',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasBooks});

  final bool hasBooks;

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
            Text(
              hasBooks
                  ? 'Aramana uyan kitap yok.'
                  : 'Kitaplığın boş.\nİlk kitabını barkod tarayarak ekle.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (hasBooks)
              Text(
                'Durum çipleriyle daraltabilirsin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

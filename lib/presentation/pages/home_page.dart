import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/platform_support.dart';
import '../../data/models/book_model.dart';
import '../controllers/library_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../widgets/book_tile.dart';

class HomePage extends GetView<LibraryController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitaplığım'),
        actions: [
          // Çok raf/çok kitap kütüphanelerinde doğrudan rafa atlama.
          IconButton(
            tooltip: 'Raflar',
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: () => _showShelfSheet(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: _buildSearchField(),
              ),
              _buildStatusFilter(),
              _buildShelfFilter(),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = controller.filteredBooks;
                  if (items.isEmpty) {
                    return _EmptyState(hasBooks: controller.books.isNotEmpty);
                  }
                  return _buildShelfList(items);
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

  Widget _buildStatusFilter() {
    return SizedBox(
      height: 48,
      child: Obx(() {
        final selected = controller.statusFilter.value;
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Hepsi'),
                selected: selected == null,
                onSelected: (_) => controller.statusFilter.value = null,
              ),
            ),
            for (final s in ReadingStatus.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.label),
                  selected: selected == s,
                  onSelected: (_) => controller.statusFilter.value = s,
                ),
              ),
          ],
        );
      }),
    );
  }

  /// Raf filtresi: çoka raf kütüphanelerinde doğrudan rafa atlama.
  /// 'Rafsız' anahtarı raflanmamış kitapları filtreler.
  Widget _buildShelfFilter() {
    return Obx(() {
      if (controller.books.isEmpty) return const SizedBox.shrink();
      final selected = controller.shelfFilter.value;
      return SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Tümü'),
                selected: selected == null,
                onSelected: (_) => controller.shelfFilter.value = null,
              ),
            ),
            for (final key in controller.shelfFilterKeys)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$key (${controller.shelfCount(key)})'),
                  selected: selected == key,
                  onSelected: (_) => controller.shelfFilter.value = key,
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Raflara göre gruplanmış, katlanabilir bölümler.
  ///
  /// ListView.builder yalnızca görünen öğeleri kurar; katlanmış bölümler
  /// tek başlık satırıdır. Çok raf (20+) / çok kitap (raf başına 200+)
  /// kütüphanelerinde tüm listeyi tek seferde kurmak yerine bu, hem
  /// gezinmeyi hem kaydırma performansını korur.
  Widget _buildShelfList(List<BookModel> items) {
    final groups = <String, List<BookModel>>{};
    for (final b in items) {
      final key = b.shelf.trim().isEmpty ? 'Rafsız' : b.shelf.trim();
      groups.putIfAbsent(key, () => []).add(b);
    }

    final descriptors = <_HomeItem>[];
    for (final entry in groups.entries) {
      final collapsed = controller.collapsedShelves.contains(entry.key);
      descriptors.add(_HomeItem.header(entry.key, entry.value.length));
      if (!collapsed) {
        for (final book in entry.value) {
          descriptors.add(_HomeItem.bookItem(book));
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      itemCount: descriptors.length,
      itemBuilder: (context, index) {
        final item = descriptors[index];
        if (item.shelfKey != null) {
          return _ShelfHeader(
            key: ValueKey('shelf-${item.shelfKey}'),
            shelfKey: item.shelfKey!,
            count: item.count,
          );
        }
        final book = item.book!;
        return BookTile(
          key: ValueKey(book.id),
          book: book,
          onTap: () => Get.toNamed(Routes.detail, arguments: book.id),
        );
      },
    );
  }

  void _showShelfSheet(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.shelves, size: 20),
                    const SizedBox(width: 8),
                    Text('Raflar', style: Get.textTheme.titleMedium),
                  ],
                ),
              ),
              Flexible(
                child: Obx(() {
                  final keys = controller.shelfFilterKeys;
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.apps),
                        title: const Text('Tüm raflar'),
                        selected: controller.shelfFilter.value == null,
                        onTap: () {
                          Get.back();
                          controller.shelfFilter.value = null;
                        },
                      ),
                      for (final key in keys)
                        ListTile(
                          leading: const Icon(Icons.shelves),
                          title: Text(key),
                          trailing: Text('${controller.shelfCount(key)} kitap'),
                          selected: controller.shelfFilter.value == key,
                          onTap: () {
                            Get.back();
                            controller.shelfFilter.value = key;
                          },
                        ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
    );
  }

  void _showAddSheet(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (PlatformSupport.supportsBarcodeScan)
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

/// Katlanabilir raf başlığı; dokunulduğunda bölüm açılır/kapanır.
class _ShelfHeader extends GetView<LibraryController> {
  const _ShelfHeader({
    super.key,
    required this.shelfKey,
    required this.count,
  });

  final String shelfKey;
  final int count;

  @override
  Widget build(BuildContext context) {
    final collapsed = controller.collapsedShelves.contains(shelfKey);
    return InkWell(
      onTap: () => controller.toggleShelfCollapsed(shelfKey),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
        child: Row(
          children: [
            const Icon(Icons.shelves, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$shelfKey ($count)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// ListView.builder için hafif öğe tanımı: başlık ya da kitap.
class _HomeItem {
  const _HomeItem.header(this.shelfKey, this.count) : book = null;
  const _HomeItem.bookItem(this.book) : shelfKey = null, count = 0;

  final String? shelfKey;
  final int count;
  final BookModel? book;
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
                'Raf çipleriyle doğrudan rafa atlayabilir,\n'
                'başlığa dokunarak bölümü katlayabilirsin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      appBar: AppBar(title: const Text('Kitaplığım')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  onChanged: (v) => controller.query.value = v,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Kitap, yazar veya raf ara',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              _buildStatusFilter(),
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

  Widget _buildShelfList(List<BookModel> items) {
    final groups = <String, List<BookModel>>{};
    for (final b in items) {
      final key = b.shelf.isEmpty ? 'Rafsız' : b.shelf;
      groups.putIfAbsent(key, () => []).add(b);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Row(
              children: [
                const Icon(Icons.shelves, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${entry.key} (${entry.value.length})',
                  style: Get.textTheme.titleSmall,
                ),
              ],
            ),
          ),
          for (final book in entry.value)
            BookTile(
              book: book,
              onTap: () => Get.toNamed(Routes.detail, arguments: book.id),
            ),
        ],
      ],
    );
  }

  void _showAddSheet(BuildContext context) {
    Get.bottomSheet(
      SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Barkod tara'),
              subtitle: const Text('ISBN ile Open Library\'den bilgileri getir'),
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
          ],
        ),
      ),
    );
  }
}

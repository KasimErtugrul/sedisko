import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/borrowed_book_model.dart';
import '../controllers/loan_controller.dart';
import '../utils/app_navigation.dart';
import '../widgets/borrowed_dialog.dart';

/// 'Ödünç aldıklarım' sayfası (1.18.0): başkasından ödünç aldığımız,
/// kitaplıkta olmayan kitapların takip listesi.
///
/// Sağ alttaki düğmeyle yeni kayıt eklenir; karta dokununca düzenleme
/// diyaloğu, basılı tutunca silme onayı açılır. Aktif kartta 'Geri verdim'
/// düğmesi kitabı geri verilmiş işaretler.
class BorrowedPage extends StatelessWidget {
  const BorrowedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoanController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ödünç aldıklarım')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('borrowed-add-fab'),
        onPressed: () => _add(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Kitap ekle'),
      ),
      body: Obx(() {
        final active = controller.activeBorrowed;
        final returned = controller.returnedBorrowed;
        if (active.isEmpty && returned.isEmpty) {
          return const _EmptyView();
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: [
            if (active.isNotEmpty) ...[
              _SectionHeader(title: 'Sürüyor', count: active.length),
              for (final item in active) _BorrowedCard(item: item, isActive: true),
            ],
            if (returned.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SectionHeader(title: 'Geri verilenler', count: returned.length),
              for (final item in returned)
                _BorrowedCard(item: item, isActive: false),
            ],
          ],
        );
      }),
    );
  }

  Future<void> _add(BuildContext context, LoanController controller) async {
    final result = await showBorrowedDialog(context);
    if (result == null) return;
    await controller.addBorrowed(
      title: result.$1,
      authors: _splitAuthors(result.$2),
      owner: result.$3,
      note: result.$4,
    );
  }

  /// Diyalogdan gelen virgüllü metni yazar listesine ayırır (boşlar atılır).
  static List<String> _splitAuthors(String raw) {
    if (raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _BorrowedCard extends StatelessWidget {
  const _BorrowedCard({required this.item, required this.isActive});

  final BorrowedBookModel item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = isActive
        ? 'Sahibi: ${item.owner} • alındı: ${formatDate(item.borrowedAt)}'
        : 'Sahibi: ${item.owner} • geri verildi: ${formatDate(item.returnedAt)}';

    return Card(
      key: ValueKey('borrowed-card-${item.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.authors.isNotEmpty)
              Text(
                item.authorsText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Text(subtitle),
            if (item.note != null)
              Text(
                item.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
          ],
        ),
        isThreeLine: item.authors.isNotEmpty || item.note != null,
        // Dokun → düzenle; düzenleme sonucu mevcut kaydın üzerine yazılır.
        onTap: () => _edit(context),
        trailing: isActive
            ? TextButton(
                onPressed: _markReturned,
                child: const Text('Geri verdim'),
              )
            : const Icon(Icons.check_circle_outline),
        onLongPress: () => _confirmDelete(context),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showBorrowedDialog(context, existing: item);
    if (result == null) return;
    await Get.find<LoanController>().updateBorrowed(
      item.copyWith(
        title: result.$1,
        authors: BorrowedPage._splitAuthors(result.$2),
        owner: result.$3,
        // Diyalog boş string döndürürse not temizlenir (null → alan silinir).
        note: result.$4.isEmpty ? null : result.$4,
      ),
    );
  }

  void _markReturned() async {
    final ok = await Get.find<LoanController>().markBorrowedReturned(item.id);
    if (ok) {
      Get.snackbar(
        'Geri verildi',
        '"${item.title}" ${item.owner} kişisine iade edildi.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Kayıt silinsin mi?'),
        content: Text(
          '"${item.title}" ödünç kaydı kalıcı olarak silinecek. Bu kayıt '
          'kitaplığa bağlı değildir; silmek kitaplığı etkilemez.',
        ),
        actions: [
          TextButton(
            onPressed: () => AppNav.pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              AppNav.pop(); // diyalog
              await Get.find<LoanController>().removeBorrowed(item.id);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.import_contacts_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Henüz başkasından ödünç aldığın kitap yok.\n'
              'Sağ alttaki düğmeyle ekleyebilirsin.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

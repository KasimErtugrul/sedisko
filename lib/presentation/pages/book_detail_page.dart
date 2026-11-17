import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/book_model.dart';
import '../controllers/library_controller.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../widgets/cover_image.dart';
import '../widgets/reading_stats_panel.dart';

class BookDetailPage extends GetView<LibraryController> {
  const BookDetailPage({super.key});

  /// Argümanı savunmacı biçimde okur: hatalı tip/boş argümanda `null`
  /// döner; `Get.arguments as String` cast'ı gibi crash üretmez.
  String? get _bookId {
    final arg = Get.arguments;
    if (arg is String && arg.isNotEmpty) return arg;
    if (arg is Map) {
      final id = arg['id'] ?? arg['bookId'];
      if (id is String && id.isNotEmpty) return id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final id = _bookId;
      final book = id == null ? null : controller.byId(id);
      if (book == null) {
        return _NotFoundScaffold(hasArgs: id != null);
      }
      final theme = Theme.of(context);

      return Scaffold(
        appBar: AppBar(
          title: const Text('Kitap detayı'),
          actions: [
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit),
              onPressed: () => Get.toNamed(
                Routes.form,
                arguments: BookFormArgs(book: book, isEdit: true),
              ),
            ),
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(book),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverImage(url: book.coverUrl, width: 100, height: 150),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: theme.textTheme.titleLarge),
                      if (book.authors.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(book.authorsText, style: theme.textTheme.bodyLarge),
                      ],
                      const SizedBox(height: 8),
                      if (book.publisher != null)
                        Text(book.publisher!, style: theme.textTheme.bodySmall),
                      if (book.publishDate != null)
                        Text('Basım: ${book.publishDate}',
                            style: theme.textTheme.bodySmall),
                      if (book.pageCount > 0)
                        Text('${book.pageCount} sayfa',
                            style: theme.textTheme.bodySmall),
                      if (book.isbn != null)
                        Text('ISBN: ${book.isbn}',
                            style: theme.textTheme.bodySmall),
                      if (book.isManual)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Chip(
                            label: Text('Manuel giriş'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shelves),
                title: const Text('Raf'),
                subtitle:
                    Text(book.shelf.isEmpty ? 'Belirtilmedi' : book.shelf),
              ),
            ),
            const SizedBox(height: 8),
            _readingCard(context, book),
            if (book.notes != null) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notes),
                  title: const Text('Not'),
                  subtitle: Text(book.notes!),
                ),
              ),
            ],
            const SizedBox(height: 8),
            ReadingStatsPanel(book: book),
          ],
        ),
      );
    });
  }

  Widget _readingCard(BuildContext context, BookModel book) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Okuma durumu', style: theme.textTheme.titleMedium),
                const Spacer(),
                Chip(
                  label: Text(book.status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (book.status != ReadingStatus.notStarted) ...[
              const SizedBox(height: 8),
              if (book.pageCount > 0) ...[
                LinearProgressIndicator(value: book.progress),
                const SizedBox(height: 6),
              ],
              Text(
                book.pageCount > 0
                    ? 'Sayfa ${book.currentPage} / ${book.pageCount} '
                        '(%${(book.progress * 100).round()})'
                    : 'Sayfa ${book.currentPage}',
              ),
              const SizedBox(height: 4),
              Text('Başlangıç: ${formatDate(book.startedAt)}'),
              if (book.status == ReadingStatus.finished)
                Text('Bitiş: ${formatDate(book.finishedAt)}'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (book.status == ReadingStatus.notStarted)
                  FilledButton.icon(
                    onPressed: () => controller.startReading(book),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Okumaya başla'),
                  ),
                if (book.status == ReadingStatus.reading) ...[
                  FilledButton.icon(
                    onPressed: () => Get.dialog(_UpdatePageDialog(book: book)),
                    icon: const Icon(Icons.bookmark),
                    label: const Text('Sayfayı güncelle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => controller.markFinished(book),
                    icon: const Icon(Icons.check),
                    label: const Text('Bitirdim'),
                  ),
                ],
                if (book.status == ReadingStatus.finished)
                  OutlinedButton.icon(
                    onPressed: () => controller.restartReading(book),
                    icon: const Icon(Icons.replay),
                    label: const Text('Yeniden oku'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BookModel book) {
    Get.dialog(
      AlertDialog(
        title: const Text('Kitap silinsin mi?'),
        content: Text('"${book.title}" kitaplıktan kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              Get.back(); // diyalog
              // Silme başarılıysa detay sayfasından çık; başarısızsa
              // kal (hata mesajı LibraryController'da gösterilir).
              final ok = await controller.deleteBook(book.id);
              if (ok) Get.back();
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

/// Kitap bulunamadığında (silinmiş/hatalı argüman) boş bir ekran yerine
/// kullanıcıyı yönlendiren bilgilendirici sayfa.
class _NotFoundScaffold extends StatelessWidget {
  const _NotFoundScaffold({required this.hasArgs});

  final bool hasArgs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitap detayı')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasArgs
                  ? 'Bu kitap artık kitaplıkta değil.'
                  : 'Kitap bilgisi alınamadı.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: Get.back,
              child: const Text('Geri dön'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdatePageDialog extends StatefulWidget {
  const _UpdatePageDialog({required this.book});

  final BookModel book;

  @override
  State<_UpdatePageDialog> createState() => _UpdatePageDialogState();
}

class _UpdatePageDialogState extends State<_UpdatePageDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.book.currentPage}');

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String raw) {
    final page = int.tryParse(raw.trim());
    if (page == null || page < 0) return 'Geçerli bir sayfa numarası gir';
    final total = widget.book.pageCount;
    if (total > 0 && page > total) {
      return 'Toplam sayfadan büyük olamaz ($total)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kaçıncı sayfadasın?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          errorText: _error,
          suffixText:
              widget.book.pageCount > 0 ? '/ ${widget.book.pageCount}' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final error = _validate(_controller.text);
            if (error != null) {
              setState(() => _error = error);
              return;
            }
            final page = int.tryParse(_controller.text.trim()) ?? 0;
            Get.back();
            Get.find<LibraryController>().updateProgress(widget.book, page);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

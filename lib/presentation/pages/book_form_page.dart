import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/utils/date_formatter.dart';
import '../../core/utils/platform_support.dart';
import '../../data/models/book_model.dart';
import '../controllers/book_form_controller.dart';
import '../widgets/cover_image.dart';

class BookFormPage extends GetView<BookFormController> {
  const BookFormPage({super.key});

  static const _border = OutlineInputBorder();

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      appBar: AppBar(title: Text(c.isEdit ? 'Kitabı düzenle' : 'Yeni kitap')),
      body: Form(
        key: c.formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _isbnRow(c),
            Obx(() {
              final url = c.coverUrl.value;
              if (url == null || url.isEmpty) return const SizedBox(height: 16);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child:
                    Center(child: CoverImage(url: url, width: 90, height: 130)),
              );
            }),
            TextFormField(
              controller: c.titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Kitap adı *',
                border: _border,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Kitap adı gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: c.authorsCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Yazar(lar)',
                hintText: 'Birden fazlaysa virgülle ayır',
                border: _border,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: c.pagesCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Sayfa sayısı',
                      border: _border,
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return null; // bilinmiyorsa boş kalabilir
                      final pages = int.tryParse(value);
                      if (pages == null || pages <= 0) {
                        return 'Geçerli bir sayı gir';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: c.publishDateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Basım yılı',
                      hintText: 'örn. 2021',
                      border: _border,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: c.publisherCtrl,
              decoration: const InputDecoration(
                labelText: 'Yayınevi',
                border: _border,
              ),
            ),
            const SizedBox(height: 24),
            Text('Konum', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: c.shelfCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Raf *',
                hintText: 'örn. Salon - 2. raf',
                prefixIcon: Icon(Icons.shelves),
                border: _border,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Raf bilgisi gerekli' : null,
            ),
            if (c.shelves.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final s in c.shelves)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => c.shelfCtrl.text = s,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text('Okuma durumu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Obx(
              () => SegmentedButton<ReadingStatus>(
                showSelectedIcon: false,
                // Küçük ekranlarda Türkçe etiketler taşmayacak şekilde sığdır.
                style: const ButtonStyle(
                  visualDensity: VisualDensity(horizontal: -3),
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
                ),
                segments: [
                  for (final s in ReadingStatus.values)
                    ButtonSegment(
                      value: s,
                      label: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                selected: {c.status.value},
                onSelectionChanged: (set) => c.setStatus(set.first),
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final s = c.status.value;
              return Column(
                children: [
                  if (s != ReadingStatus.notStarted) ...[
                    TextFormField(
                      controller: c.currentPageCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Kaldığın sayfa',
                        border: _border,
                      ),
                      validator: (v) {
                        final p = int.tryParse((v ?? '').trim());
                        if (p == null) return 'Geçerli bir sayfa gir';
                        final total = int.tryParse(c.pagesCtrl.text.trim()) ?? 0;
                        if (total > 0 && p > total) {
                          return 'Toplam sayfadan büyük olamaz';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _dateField(context, 'Başlangıç tarihi', c.startedAt),
                  ],
                  if (s == ReadingStatus.finished) ...[
                    const SizedBox(height: 12),
                    _dateField(context, 'Bitiş tarihi', c.finishedAt),
                  ],
                ],
              );
            }),
            const SizedBox(height: 12),
            TextFormField(
              controller: c.notesCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Not',
                alignLabelWithHint: true,
                border: _border,
              ),
            ),
            const SizedBox(height: 24),
            Obx(
              () => FilledButton.icon(
                onPressed: c.isSaving.value ? null : c.save,
                icon: c.isSaving.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Kaydet'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _isbnRow(BookFormController c) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: c.isbnCtrl,
            // ISBN-10'un son hanesi 'X' olabildiği için metin klavyesi +
            // kısıtlı formatter kullanılır; sayısal klavye X yazamaz.
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9xX\- ]')),
            ],
            decoration: const InputDecoration(
              labelText: 'ISBN',
              hintText: '978-3-16-148410-0',
              border: _border,
            ),
            validator: c.validateIsbn,
          ),
        ),
        const SizedBox(width: 8),
        Obx(
          () => c.isFetching.value
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton.filledTonal(
                  tooltip: "Open Library'den getir",
                  onPressed: c.fetchFromOpenLibrary,
                  icon: const Icon(Icons.cloud_download_outlined),
                ),
        ),
        if (PlatformSupport.supportsBarcodeScan)
          IconButton.filledTonal(
            tooltip: 'Barkod tara',
            onPressed: c.scanIsbn,
            icon: const Icon(Icons.qr_code_scanner),
          ),
      ],
    );
  }

  Widget _dateField(BuildContext context, String label, Rxn<DateTime> value) {
    return Obx(
      () => InkWell(
        onTap: () => controller.pickDate(context, value),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: _border,
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(formatDate(value.value)),
        ),
      ),
    );
  }
}

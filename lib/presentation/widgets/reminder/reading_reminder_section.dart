/// Ayarlar sayfasına gömülen okuma hatırlatıcısı bölümü (1.18.0 sürümüyle
/// eklendi).
///
/// Bölüm kendi küçük başlığını, aç/kapat anahtarını ve (açıkken) saat ile
/// günlük sayfa hedefi satırlarını çizer. Denetleyici BUILD sırasında aranmaz
/// ([ReadingReminderController] dokunma anında çözümlenir); shell testleri
/// bölümü denetleyicisiz kurabilmelidir: kayıtlı değilse sessizce boş
/// kurulur.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/reminder_controller.dart';

/// Ayarlar sayfasındaki günlük okuma hatırlatıcısı bölümü.
class ReadingReminderSection extends StatelessWidget {
  const ReadingReminderSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ReadingReminderController>()) {
      // Denetleyici kayıtlı değil (örn. izole shell testleri): hiçbir şey
      // çizme; ayarlar listesi hatasız kurulmaya devam etsin.
      return const SizedBox.shrink();
    }
    final controller = Get.find<ReadingReminderController>();
    return Obx(
      () {
        final enabled = controller.enabled.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ReminderSectionHeader('Okuma hatırlatıcısı'),
            SwitchListTile(
              value: enabled,
              onChanged: controller.toggle,
              title: const Text('Günlük okuma hatırlatıcısı'),
              subtitle: const Text(
                'Seçtiğin saatte günlük sayfa hedefini bildirir',
              ),
            ),
            if (enabled) ...[
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Hatırlatma saati'),
                trailing: Text(
                  _clockLabel(controller.hour.value, controller.minute.value),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: controller.hour.value,
                      minute: controller.minute.value,
                    ),
                  );
                  if (picked != null) await controller.setTime(picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Günlük sayfa hedefi'),
                trailing: Text('${controller.pages.value} sayfa'),
                onTap: () => _showPagesDialog(context, controller),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Saat:dakika etiketi; iki hane padlenir (örn. '08:05').
  static String _clockLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Günlük sayfa hedefi girişi: mevcut değer dolu bir sayfa alanı,
  /// 'Kaydet' güvenli ayrıştırma yapar, 'Vazgeç' hiçbir şey değiştirmez.
  ///
  /// Metin alanının denetleyicisi [_PagesDialog]'a aittir: kapatma
  /// animasyonu bitmeden dispose edilmez (kullanım sonrası dispose hatası
  /// olmaz). Geçerli değer doğrudan [showDialog] sonucu döner.
  Future<void> _showPagesDialog(
    BuildContext context,
    ReadingReminderController controller,
  ) async {
    final saved = await showDialog<int>(
      context: context,
      builder: (_) => _PagesDialog(initialPages: controller.pages.value),
    );
    if (saved == null) return;
    await controller.setPages(saved);
  }
}

/// Günlük sayfa hedefi diyaloğu.
class _PagesDialog extends StatefulWidget {
  const _PagesDialog({required this.initialPages});

  final int initialPages;

  @override
  State<_PagesDialog> createState() => _PagesDialogState();
}

class _PagesDialogState extends State<_PagesDialog> {
  late final TextEditingController _input =
      TextEditingController(text: '${widget.initialPages}');

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Günlük sayfa hedefi'),
      content: TextField(
        controller: _input,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Sayfa',
          hintText: 'Örn. 20',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            // Geçersiz girişte null döner: çağıran taraf hiçbir şey yapmaz.
            final value = int.tryParse(_input.text.trim());
            Navigator.of(context).pop(value);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Bölüm başlığı; ayarlar sayfasındaki bölüm başlığı stiline benzer.
class _ReminderSectionHeader extends StatelessWidget {
  const _ReminderSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

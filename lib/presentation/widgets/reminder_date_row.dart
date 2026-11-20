import 'package:flutter/material.dart';

import '../../core/utils/date_formatter.dart';

/// Keşke 34/35 (1.26.0): ödünç diyaloglarının hatırlatma günü satırı.
///
/// Hasan'ın notları: "Kitabı kimin aldığını uygulama biliyor; ama ne zaman
/// geri isteyeceğim benim aklımda kalıyor" (ödünç verilen) ve "Komşunun
/// kitabı altı aydır bende; kimse beni uyarmıyor" (ödünç alınan). Satır
/// hızlı çiplerle (+1 hafta / +2 hafta / +1 ay), takvimden kendi tarihi
/// seçme yoluyla ve temizleme düğmesiyle çalışır: hiçbir alan zorunlu
/// değildir, eski davranış (hatırlatmasız kayıt) çiplere dokunmadan aynen
/// sürer.
///
/// Saat bilinçli olarak sorulmaz: gün seçildiğinde hatırlatma o sabah
/// 09:00'a kurulur (keşke 44'ün dersi — kullanıcıya ikinci bir soru
/// sormayalım). Seçilen an geçmiş kaldıysa (örn. akşam 'bugün' seçimi)
/// ertesi sabah 09:00'a kayar; geleceğe dönülmüş her tarih kabul edilir.
class ReminderDateRow extends StatefulWidget {
  const ReminderDateRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  /// Satır başlığı ('İade hatırlatması (isteğe bağlı)' vb.).
  final String label;

  /// Seçili gün; `null` = hatırlatma yok.
  final DateTime? selected;

  /// Seçim değişince çağrılır; `null` = hatırlatma temizlendi.
  final ValueChanged<DateTime?> onChanged;

  /// Seçili günün sabah 09:00 karşılığı; geçmişe düşüyorsa ertesi sabah.
  static DateTime dayToReminder(DateTime day, {DateTime? now}) {
    var at = DateTime(day.year, day.month, day.day, 9);
    final clock = now ?? DateTime.now();
    if (!at.isAfter(clock)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  @override
  State<ReminderDateRow> createState() => _ReminderDateRowState();
}

class _ReminderDateRowState extends State<ReminderDateRow> {

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.selected ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'Hatırlatma günü seç',
    );
    if (picked == null) return;
    widget.onChanged(ReminderDateRow.dayToReminder(picked));
  }

  void _pickIn(int days) {
    final now = DateTime.now();
    widget.onChanged(
      ReminderDateRow.dayToReminder(now.add(Duration(days: days)), now: now),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ActionChip(
              key: const ValueKey('reminder-chip-week'),
              label: const Text('+1 hafta'),
              onPressed: () => _pickIn(7),
            ),
            ActionChip(
              key: const ValueKey('reminder-chip-2week'),
              label: const Text('+2 hafta'),
              onPressed: () => _pickIn(14),
            ),
            ActionChip(
              key: const ValueKey('reminder-chip-month'),
              label: const Text('+1 ay'),
              onPressed: () => _pickIn(30),
            ),
            ActionChip(
              key: const ValueKey('reminder-chip-custom'),
              label: const Text('Tarih seç...'),
              onPressed: _pickCustomDate,
            ),
            if (selected != null) ...[
              // InputDecorator Wrap içinde sınırsız genişlik ister; tarih
              // gösterimi bilinçli olarak yalın bir çerçevedir.
              Container(
                key: const ValueKey('reminder-selected'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hatırlatma: ${formatDate(selected)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    IconButton(
                      key: const ValueKey('reminder-clear'),
                      tooltip: 'Hatırlatmayı kaldır',
                      icon: const Icon(Icons.clear, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.onChanged(null),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

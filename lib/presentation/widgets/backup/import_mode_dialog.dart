import 'package:flutter/material.dart';

import '../../../data/models/backup_model.dart';
import '../../../data/services/backup_service.dart';

/// İçe aktarma kipi seçim penceresi.
///
/// Kullanıcıya yedekte ne olduğu ve iki kipin farkı net anlatılır:
/// - **Birleştir**: mevcut kitaplar korunur; yedekteki yeniler eklenir.
///   Eşin kitaplığını kendi kitaplığına katmak için güvenli seçenek.
/// - **Üzerine yaz**: mevcut kitap ve raf tanımları silinip yedeğinden
///   geri yüklenir. Eşin kitaplığını aynen kopyalamak için.
class BackupImportModeDialog extends StatelessWidget {
  const BackupImportModeDialog({super.key, required this.envelope});

  final BackupEnvelope envelope;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Yedeği nasıl içe aktaralım?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yedekte ${envelope.books.length} kitap ve '
            '${envelope.shelves.length} raf var.',
          ),
          const SizedBox(height: 16),
          Text(
            'Birleştir',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Mevcut kitaplarınız korunur; yedekteki yeni kitaplar eklenir, '
            'aynı kitaplar atlanır.',
          ),
          const SizedBox(height: 12),
          Text(
            'Üzerine yaz',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Mevcut kitap ve raf tanımları silinip yedeğinden geri yüklenir.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          // Keşke 40 (1.20.0): 'Üzerine yaz' artık iki adımlı — ilk
          // diyalog kipleri anlatır, ikinci diyalog gerçekten bütün
          // kitaplığın değişeceğini bir kez daha sorar ("basmak hâlâ tek
          // dokunuştu" notu). Onay verilmezse bu diyalog açık kalır.
          onPressed: () async {
            // Navigator'ı beklemeyi yapmadan yakala: ikinci diyalogdan
            // dönerken context'i async boşluğunun ötesinde kullanma.
            final navigator = Navigator.of(context);
            final confirmed = await _confirmOverwrite(context, envelope);
            if (confirmed) {
              navigator.pop(BackupImportMode.replace);
            }
          },
          child: Text(
            'Üzerine yaz',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(BackupImportMode.merge),
          child: const Text('Birleştir'),
        ),
      ],
    );
  }
}

/// İkinci onay: geri alınamaz adımdan önce "emin misin?" sorusu.
Future<bool> _confirmOverwrite(
  BuildContext context,
  BackupEnvelope envelope,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Bütün kitaplık değişecek'),
      content: Text(
        'Telefondaki mevcut kitaplar ve raf tanımları silinip yedektekiyle '
        'değiştirilecek. Yedekte ${envelope.books.length} kitap ve '
        '${envelope.shelves.length} raf var. Bu işlem geri alınamaz.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('overwrite-final-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Evet, hepsini değiştir'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

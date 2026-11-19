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
          onPressed: () =>
              Navigator.of(context).pop(BackupImportMode.replace),
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../controllers/backup_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/appearance/palette_picker.dart';
import '../widgets/appearance/text_scale_picker.dart';
import '../widgets/reminder/reading_reminder_section.dart';
import '../widgets/responsive/responsive_center.dart';

/// Ayarlar sekmesi: tema modu, renk paleti, yazı boyutu ve uygulama içi
/// özellik anahtarları.
///
/// Her tercih değişikliği [SettingsController] üzerinden anında uygulanır ve
/// SharedPreferences'a yazılır; uygulama bir sonraki açılışta tercihi okur.
/// Palet ve yazı boyutu dosyada tutulmaz: küçük widget'lar
/// `widgets/appearance/` altında yaşar (tanrı dosyası olmamak için).
class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('Görünüm'),
          Obx(
            () => RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: controller.themeMode.value,
              onChanged: (m) {
                if (m != null) controller.setThemeMode(m);
              },
              title: const Text('Sistem varsayılanı'),
              subtitle: const Text('Cihaz ayarını izler'),
            ),
          ),
          Obx(
            () => RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: controller.themeMode.value,
              onChanged: (m) {
                if (m != null) controller.setThemeMode(m);
              },
              title: const Text('Aydınlık'),
            ),
          ),
          Obx(
            () => RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: controller.themeMode.value,
              onChanged: (m) {
                if (m != null) controller.setThemeMode(m);
              },
              title: const Text('Karanlık'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Renk paleti'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: PalettePicker(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Yazı boyutu'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextScalePicker(),
          ),
          const Divider(height: 24),
          const _SectionHeader('Uygulama içi özellikler'),
          Obx(
            () => SwitchListTile(
              value: controller.showCovers.value,
              onChanged: controller.setShowCovers,
              title: const Text('Kapak görselleri'),
              subtitle: const Text('Kitap kapaklarını internetten göster'),
            ),
          ),
          Obx(
            () => SwitchListTile(
              value: controller.showScanActions.value,
              onChanged: controller.setShowScanActions,
              title: const Text('Barkod tarama'),
              subtitle: const Text('"Barkod tara" düğmelerini göster'),
            ),
          ),
          Obx(
            () => SwitchListTile(
              value: controller.hapticsEnabled.value,
              onChanged: controller.setHapticsEnabled,
              title: const Text('Titreşimli geri bildirim'),
              subtitle: const Text('Tarama ve dokunuşlarda titreşim'),
            ),
          ),
          const Divider(height: 24),
          // Günlük okuma hatırlatıcısı (1.18.0); denetleyicisi kayıtsızken
          // bölüm kendini boş bırakır (izole testler bozulmaz).
          const ReadingReminderSection(),
          const Divider(height: 24),
          const _SectionHeader('Yedekleme ve aktarım'),
          _BackupTiles(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              'Kitaplığım ${AppInfo.version}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

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

/// Yedekleme bölümü: paylaş + içe aktar.
///
/// Denetleyici BUILD sırasında aranmaz: Ayarlar sekmesi shell testlerinde
/// denetleyicisi kayıtlı olmadan da kurulabilmelidir. Çözümleme dokunma
/// anında yapılır; çift dokunma yine [BackupController.isBusy] ile engellenir.
class _BackupTiles extends StatelessWidget {
  const _BackupTiles();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: const Text('Yedeği paylaş (WhatsApp vb.)'),
          subtitle: const Text(
            'Tüm kitaplar ve raf tanımları tek dosyada. Paylaşım '
            'menüsünden alıcıyı (örn. WhatsApp) seçin.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Get.find<BackupController>().exportAndShare(),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Yedeği içe aktar'),
          subtitle: const Text(
            'Başka cihazdan gönderilen yedek dosyasını (örn. WhatsApp\'tan '
            'indirilen) seçin; birleştirin ya da üzerine yazın.',
          ),
          onTap: () => Get.find<BackupController>().pickBackupFile(),
        ),
      ],
    );
  }
}

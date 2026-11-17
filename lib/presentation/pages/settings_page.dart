import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../controllers/settings_controller.dart';

/// Ayarlar sekmesi: tema modu ve uygulama içi özellik anahtarları.
///
/// Her tercih değişikliği [SettingsController] üzerinden anında uygulanır ve
/// SharedPreferences'a yazılır; uygulama bir sonraki açılışta tercihi okur.
class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
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

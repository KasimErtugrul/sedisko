import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presentation/bindings/initial_binding.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/routes/app_pages.dart';
import 'presentation/routes/app_routes.dart';
import 'presentation/widgets/responsive/orientation_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Ayarlar denetleyicisi ilk kareden önce kaydedilir; GetMaterialApp
  // kayıtlı tercihe göre aydınlık/karanlık temayla açılır.
  Get.put<SettingsController>(
    SettingsController(prefs: prefs),
    permanent: true,
  );
  runApp(KitaplikApp(prefs: prefs));
}

class KitaplikApp extends StatelessWidget {
  const KitaplikApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsController>();
    return Obx(
      () {
        // Palet yalnız tohum (seed) rengini seçer; karanlık/aydınlık ayrımı
        // mevcut tema anahtarından gelir. Tohum ve ölçek Rx okumaları bu
        // Obx içinde yapıldığı için her değişiklik BÜTÜN uygulamaya anında
        // ve koşulsuz sirayet eder.
        final seed = settings.seedColor;
        final scale = settings.textScaler;
        return GetMaterialApp(
          title: 'Kitaplığım',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: seed),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
          ),
          themeMode: settings.themeMode.value,
          // Yazı boyutu: TextScaler tüm metinlere uygulanır; hiçbir ekran
          // kendi ölçeğini görmezden gelemez.
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scale),
              child: OrientationGate(child: child!),
            );
          },
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialBinding: InitialBinding(prefs),
          // Açılışta 'sedişko' karşılama ekranı (1.25.0); bekletme
          // süresi dolunca ana sayfaya geçilir (Get.offNamed).
          initialRoute: Routes.splash,
          getPages: AppPages.pages,
        );
      },
    );
  }
}

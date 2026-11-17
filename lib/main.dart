import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presentation/bindings/initial_binding.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/routes/app_pages.dart';
import 'presentation/routes/app_routes.dart';

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
      () => GetMaterialApp(
        title: 'Kitaplığım',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.brown,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: settings.themeMode.value,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        initialBinding: InitialBinding(prefs),
        initialRoute: Routes.home,
        getPages: AppPages.pages,
      ),
    );
  }
}

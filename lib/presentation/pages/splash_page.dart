import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';

/// Açılış karşılama ekranı (1.25.0).
///
/// Kullanıcının dileği: "yaaa bir de splash ekran yap be gülüm... sedişko
/// yazsın ama :)" — açılışta kısa bir selam: 'sedişko' büyük, altında
/// uygulamanın adı 'Kitaplığım'. Bekletme süresi dolunca ana sayfaya
/// geçilir ve bu ekran YIĞINDAN SİLİNİR (Get.offNamed): geri tuşu
/// karşılama ekranına döndürmez, uygulama davranışı 1.24.0'la aynıdır.
///
/// Tema kuralları aynen geçerlidir: metinler temanın tohum rengiyle
/// boyanır (karanlık/aydınlık ve palet seçimi otomatik izlenir), yazı
/// boyutu ölçeği GetMaterialApp builder'ından aynen gelir — hiçbir ekran
/// kendi ölçeğini görmezden gelemez. Veri anahtarları ve saklanan
/// veriler değişmez; ekrana hiçbir şey yazılmaz (HİÇBİR ŞEY YAZMAZ).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.holdDuration = defaultHoldDuration});

  /// Karşılamanın ekranda kalma süresi. Testler kısaltabilir.
  static const Duration defaultHoldDuration = Duration(milliseconds: 1800);

  /// Giriş animasyonunun süresi (yumuşak açılma + hafif büyüme).
  static const Duration fadeDuration = Duration(milliseconds: 600);

  final Duration holdDuration;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: SplashPage.fadeDuration)
      ..forward();
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _timer = Timer(widget.holdDuration, _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    // offNamed: karşılama ekranı yığından silinir; geri tuşu buraya
    // döndürmez. currentRoute guard'ı: testte ya da hata durumunda rota
    // başka yere alınmışsa çift gezinme yapılmaz.
    if (Get.currentRoute == Routes.splash) {
      Get.offNamed(Routes.home);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined, size: 72, color: scheme.primary),
                const SizedBox(height: 24),
                Text(
                  'sedişko',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kitaplığım',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

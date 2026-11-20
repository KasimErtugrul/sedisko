import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Keşke 44 (1.25.0): önemli haberler üç saniyelik balonlarla değil,
/// ekranda kalan bir şeritle söylensin.
///
/// Hasan'ın notu: "'Taşındı', 'Kaydedildi', 'Yazar güncellendi'... hepsi
/// alttan kayıp gidiyor. Okumaya vaktim olmuyor; balon gittiğinde ne
/// olduğunu bilmiyorum."
///
/// Bu yardımcı önemli haberleri uygulama kökündeki Overlay'e takılan bir
/// şerit olarak gösterir:
/// - Şerit 'Anladım'a dokunulana kadar EKRANDA KALIR; zamanlayıcıyla
///   kaybolmaz (snackbar'ın aksine).
/// - Şerit Snackbar kuyruğuna girmez: 'Kitap silindi — Geri Al' gibi
///   alttan çıkan öteki haberler ve AppNav.pop'un GetX snackbar
///   koruması bozulmaz.
/// - Yeni şerit eskisinin yerine geçer; şeritler yığılmaz, her zaman
///   tek şerit okunur.
/// - Şerit Scaffold'a bağımlı değildir: rota geçişlerinde (formdan
///   kaydettikten sonra ana sayfaya dönerken bile) aynen durur. Kök
///   Overlay kullanması bilinçli bir tercihtir: MaterialBanner'ın
///   ScaffoldMessenger sunumu, bir rota çıkarken şeridi iki ayrı
///   Scaffold'a birden takar; şeridin iç Hero'su aynı etiketle iki
///   yerde yaşayınca rota geçişinde Hero uçuşu başlar ve şerit
///   sıkışarak taşar (bu hata 1.25.0 testlerinde ölçüldü). Kök Overlay
///   bu tuzağı kökten yok sayar.
///
/// Kapsam bilinçli olarak dardır: yalnız Hasan'ın saydığı üç haber
/// ("Taşındı", "Kaydedildi", "Yazar güncellendi") şeride geçti; öteki
/// bildirimler (hata balonları, geri al teklifi, boş sonuç uyarıları)
/// eskisi gibi snackbar'dır — "dokunmayın" listesi bozulmaz.
OverlayEntry? _aktifGirdi;

/// Haber şeridini gösterir; varsa eski şerit kapatılıp yenisi kurulur.
void haberSeridiGoster({
  required String baslik,
  required String mesaj,
}) {
  kaldirHaberSeridi();
  // Get.key.currentState.overlay: GetX gezgininin Overlay'ine DOĞRUDAN
  // erişim (Get.overlayContext, Overlay'in ALT elemanıdır; onunla
  // Overlay.of araması boşa döner). GetMaterialApp kendi gezgin
  // anahtarını kurar; kabuk ve test ortamında her ikisinde de çalışır.
  final overlayState = Get.key.currentState?.overlay;
  if (overlayState == null) return;
  _aktifGirdi = OverlayEntry(
    builder: (context) => _HaberSeridi(baslik: baslik, mesaj: mesaj),
  );
  overlayState.insert(_aktifGirdi!);
}

/// Varsa ekranda duran haber şeridini kapatır.
///
/// [OverlayEntry.mounted] koruması: test ortamında Get.reset() ile
/// ağaç söküldüğünde girdi kendiliğinden ölür; ölü girdinin remove'u
/// çağrılmaz.
void kaldirHaberSeridi() {
  final entry = _aktifGirdi;
  _aktifGirdi = null;
  if (entry != null && entry.mounted) {
    entry.remove();
  }
}

class _HaberSeridi extends StatelessWidget {
  const _HaberSeridi({required this.baslik, required this.mesaj});

  final String baslik;
  final String mesaj;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 12,
      right: 12,
      top: 0,
      child: SafeArea(
        minimum: const EdgeInsets.only(top: 8),
        child: Material(
          key: const ValueKey('haber-seridi'),
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 6),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        baslik,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                      Text(
                        mesaj,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSecondaryContainer),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const ValueKey('haber-seridi-anladim'),
                  onPressed: kaldirHaberSeridi,
                  child: const Text('Anladım'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

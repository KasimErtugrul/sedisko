import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerController extends GetxController {
  /// [onNotify] test edilebilirlik için verilir; verilmezse GetX snackbar
  /// gösterilir.
  ScannerController({void Function(String title, String message)? onNotify})
      : _notify = onNotify ?? _defaultNotify;

  final void Function(String title, String message) _notify;

  static void _defaultNotify(String title, String message) {
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }

  /// mobile_scanner widget'ı (`useAppLifecycleState: true` varsayılanı)
  /// arka plan / ön plan geçişlerinde kamerayı otomatik durdurur ve
  /// yeniden başlatır; ayrıca bir WidgetsBindingObserver'a gerek yoktur.
  final MobileScannerController scanner = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  final torchOn = false.obs;
  final isStarting = true.obs;

  bool _handled = false;

  @override
  void onInit() {
    super.onInit();
    // Kamera/flaş durumunu kontrollü şekilde dinle: toggleTorch() çağrısı
    // başarısız olduğunda bile UI gerçek durumla senkron kalır.
    scanner.addListener(_syncTorchState);
  }

  void _syncTorchState() {
    try {
      torchOn.value = scanner.value.torchState == TorchState.on;
    } catch (_) {
      // state henüz hazır değilse varsayılanı koru.
    }
  }

  void onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        // Kamera kapanırken kullanıcıya dokunsal geri bildirim ver.
        unawaited(HapticFeedback.mediumImpact());
        unawaited(_returnWith(value));
        return;
      }
    }
  }

  /// Barkod okununca kamerayı önce durdurup sonra ekranı kapatır.
  ///
  /// Doğrudan `Get.back()` yapmak, düşük donanımlı cihazlarda kameranın
  /// bir sonraki kareyi işlemeye çalışıp karekte takılmasına yol açabilir.
  Future<void> _returnWith(String code) async {
    try {
      await scanner.stop();
    } catch (_) {
      // stop() başarısız olsa bile akış devam etsin.
    }
    Get.back(result: code);
  }

  Future<void> toggleTorch() async {
    if (_handled) return;
    try {
      await scanner.toggleTorch();
      // _syncTorchState dinleyicisi gerçek durumu yazar; ekstra işlem gerekmez.
    } catch (error) {
      torchOn.value = false;
      _notify(
        'Flaş açılamadı',
        'Bu cihazda flaş bulunmuyor olabilir. (${error.runtimeType})',
      );
    }
  }

  Future<void> retryStart() async {
    isStarting.value = true;
    try {
      await scanner.start();
    } on MobileScannerException {
      _notify(
        'Kamera başlatılamadı',
        'Kamera iznini kontrol edip tekrar deneyin.',
      );
    } catch (error) {
      _notify('Kamera başlatılamadı', '(${error.runtimeType})');
    } finally {
      isStarting.value = false;
    }
  }

  @override
  void onClose() {
    scanner.removeListener(_syncTorchState);
    unawaited(scanner.dispose());
    super.onClose();
  }
}

import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerController extends GetxController {
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
  bool _handled = false;

  void onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Get.back(result: value);
        return;
      }
    }
  }

  Future<void> toggleTorch() async {
    await scanner.toggleTorch();
    torchOn.toggle();
  }

  @override
  void onClose() {
    scanner.dispose();
    super.onClose();
  }
}

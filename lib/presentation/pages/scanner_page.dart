import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/scanner_controller.dart';

class ScannerPage extends GetView<ScannerController> {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barkod tara'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Flaş',
              icon: Icon(
                controller.torchOn.value ? Icons.flash_on : Icons.flash_off,
              ),
              onPressed: controller.toggleTorch,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller.scanner,
            onDetect: controller.onDetect,
            // Kamera izni yok / kamera kullanılamıyorsa siyah ekran yerine
            // net bir açıklama ve yeniden dene şansı sunar.
            errorBuilder: (context, error) =>
                _ScannerErrorView(error: error, onRetry: controller.retryStart),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Text(
              'Kitabın arkasındaki ISBN barkodunu çerçeveye getir',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  String get _message {
    // mobile_scanner 7.x gerçek enum değerlerine göre kullanıcı dostu
    // Türkçe mesajlar üretilir; ham detay varsa eklenir.
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Kamera izni verilmedi.\nSistem ayarlarından izni açıp '
            'tekrar dene.';
      case MobileScannerErrorCode.unsupported:
        return 'Bu cihazda barkod tarama desteklenmiyor.';
      case MobileScannerErrorCode.controllerUninitialized:
      case MobileScannerErrorCode.controllerInitializing:
      case MobileScannerErrorCode.controllerNotAttached:
        return 'Kamera henüz başlatılamadı. Tekrar dene.';
      case MobileScannerErrorCode.controllerDisposed:
      case MobileScannerErrorCode.controllerAlreadyInitialized:
      case MobileScannerErrorCode.genericError:
        final raw = error.errorDetails?.message;
        if (raw != null && raw.isNotEmpty) return 'Kamera açılamadı.\n$raw';
        return 'Kamera açılamadı. İzni kontrol edip tekrar dene.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}

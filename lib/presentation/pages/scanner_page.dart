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
           // errorBuilder: (context, child) => MobileScannerException(errorCode: ),
         /* const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Kamera açılamadı. Kamera iznini kontrol et.',
                  textAlign: TextAlign.center,
                ),
              ),
            ) */
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

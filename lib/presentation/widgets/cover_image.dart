import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/settings_controller.dart';

/// Kitap kapağı görseli.
///
/// İki kaynak desteklenir:
/// - [path]: kullanıcının çektiği kitap fotoğrafı (yerel dosya). Varsa ağ
///   kapağından önceliklidir ve ayarlardaki "Kapak görselleri (internetten
///   göster)" tercihinden bağımsızdır; kullanıcı kendi fotoğrafını görmek
///   ister.
/// - [url]: Open Library ağ kapağı; ayarlardaki tercihe saygı duyar.
///
/// Performans notları:
/// - Ağ kapaklarında `cacheWidth` verilmezse büyük kapak dosyalarının
///   piksel başına tam boyutu çözülür ve liste kaydırmada bellek şişer.
///   Hedef boyut × devicePixelRatio ile çözünürlük sınırlanır.
/// - `gaplessPlayback`, liste sıralaması değişince görsellerin boş kalıp
///   yeniden yüklenmesini önler.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    this.url,
    this.path,
    this.width = 56,
    this.height = 80,
  });

  final String? url;

  /// Yerel kitap fotoğrafının kalıcı dosya yolu (`coverPath`).
  final String? path;

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final u = url;
    final p = path;
    final hasFile = p != null && p.isNotEmpty;

    Widget resolve(bool coversEnabled) {
      if (hasFile) return _fileCover(context, p);
      if (!coversEnabled) return _placeholder(context);
      return _networkCover(context, u);
    }

    final Widget content;
    if (hasFile) {
      // Yerel fotoğraf internet kaynağı değildir; "Kapak görselleri
      // (internetten)" tercihinden bağımsız olarak gösterilir. Rx okunmadığı
      // için burada bilinçli olarak Obx yok.
      content = resolve(true);
    } else if (Get.isRegistered<SettingsController>()) {
      final settings = Get.find<SettingsController>();
      // Tercih değişince görsel anında yer tutucuya/gelecek kapağa döner.
      content = Obx(() => resolve(settings.showCovers.value));
    } else {
      content = resolve(true);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(width: width, height: height, child: content),
    );
  }

  Widget _fileCover(BuildContext context, String p) {
    return Image.file(
      File(p),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
      // Dosya yolda kaybolmuşsa (temizlenmiş, taşınmış) ağ kapağına düş.
      errorBuilder: (_, __, ___) => _networkCover(context, url),
    );
  }

  Widget _networkCover(BuildContext context, String? u) {
    if (u == null || u.isEmpty) return _placeholder(context);
    return Image.network(
      u,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _loading(context),
      errorBuilder: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _loading(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.secondaryContainer,
      alignment: Alignment.center,
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.secondaryContainer,
      child: Icon(Icons.menu_book, color: scheme.onSecondaryContainer),
    );
  }
}

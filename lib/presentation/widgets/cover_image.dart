import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Kitap kapağı görseli.
///
/// Performans notları:
/// - [Image.network] varsayılan olarak bellek önbelleği kullanır; ancak
///   `cacheWidth` verilmemesi, büyük kapak dosyalarının piksel başına tam
///   boyutunu çözer ve liste kaydırmada belleği şişirir. Hedef boyut ×
///   devicePixelRatio ile çözünürlük sınırlanır.
/// - `gaplessPlayback`, liste sıralaması değişince görsellerin boş kalıp
///   yeniden yüklenmesini önler.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    this.url,
    this.width = 56,
    this.height = 80,
  });

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: (u == null || u.isEmpty)
            ? _placeholder(context)
            : CachedNetworkImage(
                imageUrl: u,
                fit: BoxFit.cover,
                memCacheWidth:
                    (width * MediaQuery.devicePixelRatioOf(context)).round(),
                filterQuality: FilterQuality.medium,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                progressIndicatorBuilder: (context, url, progress) =>
                    _loading(context),
                errorWidget: (context, url, error) => _placeholder(context),
              ),
      ),
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

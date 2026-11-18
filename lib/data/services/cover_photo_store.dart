import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Kitabın fotoğrafının kalıcı kopyasını tutan depo.
///
/// image_picker çekilen/seçilen fotoğrafı geçici (temp) klasöre yazar;
/// sistem bu klasörü her an temizleyebilir. Bu yüzden dosya uygulamanın
/// belgeler dizini altındaki `covers/` klasörüne **kopyalanır** ve kitap
/// kaydında yalnızca bu kalıcı yol saklanır (`coverPath`).
///
/// Test edilebilirlik: kurucu [baseDir] alır; verilmezse gerçek belgeler
/// dizini kullanılır. Testler geçici klasör vererek platform kanalı
/// olmadan aynı kodu çalıştırır.
class CoverPhotoStore {
  CoverPhotoStore({Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  Future<Directory> _coversDir() async {
    final dir = Directory(
      '${(await _baseDir()).path}${Platform.pathSeparator}covers',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// [sourcePath]'teki (genellikle image_picker temp dosyası) fotoğrafı
  /// kalıcı `covers/` klasörüne kopyalar; kalıcı yolu döner.
  Future<String> saveFromTemp(String sourcePath) async {
    final source = File(sourcePath);
    final dir = await _coversDir();

    // Uzantıyı koru; gelmiyorsa .jpg varsay.
    final dot = sourcePath.lastIndexOf('.');
    final slash = sourcePath.lastIndexOf(Platform.pathSeparator);
    final ext = dot > slash ? sourcePath.substring(dot) : '.jpg';

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final target =
        File('${dir.path}${Platform.pathSeparator}cover_$stamp$ext');
    await source.copy(target.path);
    return target.path;
  }

  /// [path] fotoğrafını siler. Yalnızca `covers/` klasörünün içindeki
  /// dosyalar silinir: bozuk/yabancı bir yol kayıtta kalırsa kullanıcının
  /// başka dosyalarına dokunulmaz. Temizlik hatası kitap verisini
  /// etkilemez; sessizce yutulur.
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final dir = await _coversDir();
      final file = File(path);
      if (!file.absolute.path.startsWith(dir.absolute.path)) return;
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Temizlik başarısız olabilir; veri bozulmaz.
    }
  }
}

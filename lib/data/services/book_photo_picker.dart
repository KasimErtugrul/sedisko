import 'package:image_picker/image_picker.dart';

/// Kitap fotoğrafı kaynağı: kamera çekimi ya da galeriden seçim.
///
/// Dönen yol **geçici** (temp) bir dosya yoludur; çağıran taraf kalıcı
/// kopyayı `CoverPhotoStore.saveFromTemp` ile alır. Arayüz testlerde
/// sahte kaynakla değiştirilebilir.
abstract class BookPhotoPicker {
  /// Kamerayla fotoğraf çeker; vazgeçilirse `null` döner.
  Future<String?> takePhoto();

  /// Galeriden fotoğraf seçer; vazgeçilirse `null` döner.
  Future<String?> pickFromGallery();
}

/// image_picker tabanlı gerçekleştirme.
class ImagePickerBookPhotoPicker implements BookPhotoPicker {
  ImagePickerBookPhotoPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> takePhoto() => _pick(ImageSource.camera);

  @override
  Future<String?> pickFromGallery() => _pick(ImageSource.gallery);

  /// 1200 px üst sınır + %80 kalite: detay/liste gösterimi için
  /// yeterli nettir, diskte ve bellekte şişkinlik yapmaz.
  Future<String?> _pick(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 80,
    );
    return xfile?.path;
  }
}

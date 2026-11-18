/// Platforma göre özellik kullanılabilirliğini belirler.
library;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class PlatformSupport {
  const PlatformSupport._();

  /// mobile_scanner paketinin desteklediği platformlarda barkod tarama
  /// açılabilir. Windows/Linux'ta paket desteği yoktur; ilgili butonlar
  /// bu platformlarda gizlenir.
  ///
  /// Not: Web, macOS, Android ve iOS desteklenir.
  static bool get supportsBarcodeScan {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return false;
    }
  }

  /// Kitap fotoğrafı ekleme (kamera + galeri). image_picker paketi mobil
  /// platformlarda çalışır; masaüstü ve web'te fotoğraf bölümü gizlenir
  /// (kapaklar yalnız Open Library URL'sinden gelir).
  static bool get supportsPhotoAttach {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return false;
    }
  }
}

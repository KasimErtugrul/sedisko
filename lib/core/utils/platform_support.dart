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
}

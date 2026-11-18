import 'package:flutter/material.dart';

/// Tek bir renk paleti: kimlik, görünen ad ve tema tohum (seed) rengi.
///
/// Palet yalnız tohum rengi seçer; karanlık/aydınlık ayrımı mevcut tema
/// anahtarından bağımsız kalır. [ColorScheme.fromSeed] her iki parlaklıkta
/// da uyumlu ton türetir.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.seed,
  });

  /// Kalıcılıkta kullanılan kararlı kimlik ('varsayilan', 'orman' vb.).
  final String id;

  /// Ayarlar ekranında görünen Türkçe ad.
  final String name;

  /// Tema tohumu; açık ve koyu şemalar buradan türetilir.
  final Color seed;
}

/// Hazır palet seti + özel renk çözümlemesi.
///
/// Kullanıcı ya hazır paletlerden seçer ya da "Özel" yolundan kendi
/// tohum rengini (hue kaydırıcısıyla) belirler; özel renk ARGB int olarak
/// saklanır ve `settings_custom_seed` anahtarında kalıcılaşır.
class AppPalettes {
  const AppPalettes._();

  /// Varsayılan palet kimliği (eski kullanıcılar için açılış rengi).
  static const String defaultId = 'varsayilan';

  /// Kullanıcının kendi seçtiği rengin kimliği.
  static const String customId = 'custom';

  /// Yazı boyutu kademeleri; ayarlar ekranındaki seçeneklerle aynıdır.
  static const List<double> textScales = [0.85, 1.0, 1.15, 1.3];

  /// Varsayılan yazı boyutu çarpanı.
  static const double defaultTextScale = 1.0;

  /// Hazır paletler; sıra ayarlar ekranındaki sırayla aynıdır.
  static const List<AppPalette> presets = [
    AppPalette(
      id: 'varsayilan',
      name: 'Varsayılan',
      seed: Color(0xFF1565C0), // mavi
    ),
    AppPalette(
      id: 'orman',
      name: 'Orman',
      seed: Color(0xFF2E7D32), // yeşil
    ),
    AppPalette(
      id: 'gunbatimi',
      name: 'Gün Batımı',
      seed: Color(0xFFEF6C00), // turuncu
    ),
    AppPalette(
      id: 'lavanta',
      name: 'Lavanta',
      seed: Color(0xFF6750A4), // mor
    ),
    AppPalette(
      id: 'deniz',
      name: 'Deniz',
      seed: Color(0xFF00838F), // camgöbeği
    ),
    AppPalette(
      id: 'gul',
      name: 'Gül',
      seed: Color(0xFFC2185B), // pembe
    ),
  ];

  /// Kimliğe göre hazır palet; bilinmeyen kimlikte `null`.
  static AppPalette? byId(String id) {
    for (final palette in presets) {
      if (palette.id == id) return palette;
    }
    return null;
  }

  /// Tohum rengini çözümler: özel kimlik ve geçerli ARGB varsa kullanıcı
  /// rengi, değilse hazır palet; o da bilinmiyorsa varsayılan palet.
  ///
  /// Depolanmış veri bozuk olsa bile uygulama her zaman geçerli bir
  /// renkle açılır (savunmacı çözümleme). Geçerli ARGB aralığı
  /// 0..0xFFFFFFFF'tir (Color.value 64-bit VM'de pozitiftir).
  static Color resolveSeed(String paletteId, int customSeedArgb) {
    if (paletteId == customId &&
        customSeedArgb >= 0 &&
        customSeedArgb <= 0xFFFFFFFF) {
      return Color(customSeedArgb);
    }
    return byId(paletteId)?.seed ?? byId(defaultId)!.seed;
  }

  /// Depolanan ölçek değeri geçerli bir kademe mi? (bozuk veriye karşı)
  static bool isValidTextScale(double scale) =>
      textScales.any((s) => s == scale);
}

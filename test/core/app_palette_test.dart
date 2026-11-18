import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/core/theme/app_palette.dart';

void main() {
  group('AppPalettes hazır paletler', () {
    test('altı hazır palet tanımlıdır', () {
      expect(AppPalettes.presets, hasLength(6));
    });

    test('palet kimlikleri benzersizdir', () {
      final ids = AppPalettes.presets.map((p) => p.id).toSet();
      expect(ids, hasLength(AppPalettes.presets.length));
    });

    test('tohum renkleri benzersizdir ve opaktır', () {
      final seeds = AppPalettes.presets.map((p) => p.seed).toSet();
      expect(seeds, hasLength(AppPalettes.presets.length));
      for (final palette in AppPalettes.presets) {
        expect(palette.seed.alpha, 255);
      }
    });

    test('byId bilinen kimliği bulur, bilinmeyeni null döner', () {
      expect(AppPalettes.byId('varsayilan'), isNotNull);
      expect(AppPalettes.byId('orman')?.name, 'Orman');
      expect(AppPalettes.byId('yok_boyle_palet'), isNull);
      expect(AppPalettes.byId(AppPalettes.customId), isNull);
    });

    test('varsayılan palet her zaman listede vardır', () {
      expect(AppPalettes.byId(AppPalettes.defaultId), isNotNull);
    });
  });

  group('AppPalettes.resolveSeed', () {
    test('hazır palet kimliği paletin tohumunu döner', () {
      final orman = AppPalettes.byId('orman')!;
      expect(
        AppPalettes.resolveSeed('orman', 0),
        orman.seed,
      );
    });

    test('özel kimlik ve geçerli ARGB kullanıcı rengini döner', () {
      // Color.value 64-bit VM'de pozitiftir (0..0xFFFFFFFF).
      final argb = const Color(0xFF123456).value;
      expect(argb, greaterThan(0));
      expect(
        AppPalettes.resolveSeed(AppPalettes.customId, argb),
        const Color(0xFF123456),
      );
    });

    test('özel kimlikte geçersiz ARGB varsayılan palete düşer', () {
      final fallback = AppPalettes.byId(AppPalettes.defaultId)!.seed;
      expect(AppPalettes.resolveSeed(AppPalettes.customId, -1), fallback);
      expect(AppPalettes.resolveSeed(AppPalettes.customId, -5), fallback);
      expect(
        AppPalettes.resolveSeed(AppPalettes.customId, 0x1FFFFFFFF),
        fallback,
        reason: '0xFFFFFFFF üstü aralık dışıdır',
      );
    });

    test('bilinmeyen palet kimliği varsayılan palete düşer', () {
      final fallback = AppPalettes.byId(AppPalettes.defaultId)!.seed;
      expect(AppPalettes.resolveSeed('bozuk_veri', 0), fallback);
    });
  });

  group('yazı boyutu kademeleri', () {
    test('dört kademe tanımlıdır ve 1.0 içerir', () {
      expect(AppPalettes.textScales, hasLength(4));
      expect(AppPalettes.textScales, contains(1.0));
    });

    test('isValidTextScale yalnız tanımlı kademeleri kabul eder', () {
      for (final scale in AppPalettes.textScales) {
        expect(AppPalettes.isValidTextScale(scale), isTrue, reason: '$scale');
      }
      expect(AppPalettes.isValidTextScale(1.2), isFalse);
      expect(AppPalettes.isValidTextScale(0.5), isFalse);
      expect(AppPalettes.isValidTextScale(2.0), isFalse);
    });
  });
}

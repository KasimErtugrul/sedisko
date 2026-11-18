import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_breakpoints.dart';

/// Yönelim kapısı: telefonu dikeye kilitler, tablet/geniş cihazı serbest
/// bırakır.
///
/// Kullanıcı tercihi: yatay (landscape) düzen yalnız tablet ölçeğinde
/// (~600 dp+ en kısa kenar) devreye girer; telefon dikey kilitli kalır.
/// Kural cihazın en kısa kenarına bakılır (dar yüz), o anki yönüne değil:
/// böylece tablet yataya dönerken kural tersine dönmez.
///
/// Karar fonksiyonu saf tutulur; platform çağrısı ateşle-unut (fire-and-
/// forget) yapılır ve yalnız karar değiştiğinde gönderilir (gereksiz
/// kanal trafiği olmaz). Widget testlerinde platform kanalı sessizdir.
class OrientationGate extends StatefulWidget {
  const OrientationGate({super.key, required this.child});

  final Widget child;

  /// Verilen en kısa kenara (dp) uygun yönelim kümesi.
  ///
  /// Telefon (< 600 dp): yalnız dikey. Tablet/geniş: dört yön serbest
  /// (iPad plist'iyle aynı küme; masaüstü pencerelerinde etkisizdir).
  static List<DeviceOrientation> orientationsFor(double shortestSide) {
    if (shortestSide < AppBreakpoints.wide) {
      return const [DeviceOrientation.portraitUp];
    }
    return const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];
  }

  @override
  State<OrientationGate> createState() => _OrientationGateState();
}

class _OrientationGateState extends State<OrientationGate> {
  List<DeviceOrientation>? _lastApplied;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // BoxConstraints'ta shortestSide yok: en kısa kenar = min(w, h).
        final shortestSide = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final wanted = OrientationGate.orientationsFor(shortestSide);
        final changed = _lastApplied == null ||
            !_listEquals(_lastApplied!, wanted);
        if (changed) {
          _lastApplied = wanted;
          unawaited(SystemChrome.setPreferredOrientations(wanted));
        }
        return widget.child;
      },
    );
  }

  static bool _listEquals(List<DeviceOrientation> a, List<DeviceOrientation> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

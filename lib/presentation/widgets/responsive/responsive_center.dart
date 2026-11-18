import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

/// Geniş ekranda içeriği ortada, okunabilir tavan genişlikte tutan sarmalayıcı.
///
/// Dar ekranda hiçbir etkisi yoktur (çocuk tam genişlikte akar); geniş
/// ekranda çocuk [AppBreakpoints.contentMax] (ya da çağıranın verdiği
/// [maxWidth]) genişlikle ortalanır. Uzun liste satırlarının tablette
/// iki uç arasında dağılmaması için kullanılır.
///
/// Yükseklik kısıtı değişmez: kaydırılabilir çocuklar (ListView vb.)
/// olduğu gibi tam yükseklikte akar.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// Tavan genişlik; verilmezse [AppBreakpoints.contentMax] kullanılır.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final limit = maxWidth ?? AppBreakpoints.contentMax;
        final effective = constraints.maxWidth >= limit ? limit : null;
        return Center(
          child: effective == null
              ? child
              : ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: effective),
                  child: child,
                ),
        );
      },
    );
  }
}

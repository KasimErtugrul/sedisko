import 'package:flutter/material.dart';

/// Responsive kırılım (breakpoint) sabitleri.
///
/// Uygulama tek eşik etrafında düşünür: 600 dp altı "dar" (telefon),
/// 600 dp ve üzeri "geniş" (tablet / masaüstü penceresi / yatay tablet).
/// Geniş ekranda alt navigasyon yerini [NavigationRail]'e bırakır ve
/// liste içerikleri okunabilirlik için ortada tavan genişlikte durur.
///
/// Eşik Material yönergelerindeki "medium window" (600dp) değeridir;
/// telefonların yatay genişliği de 600+ olabildiğinden yatay telefonda
/// rail düzeni doğal olarak devreye girer (yönelim kapısı telefonu
/// yataya döndürmediği için pratikte tablet/yatay serbest cihazlarda
/// görülür).
class AppBreakpoints {
  const AppBreakpoints._();

  /// Dar ↔ geniş eşiği (logik dp).
  static const double wide = 600;

  /// Çok geniş ekranda liste içeriğinin tavan genişliği: daha genişte
  /// satırlar okunamayacak kadar uzamaz, içerik ortalanır.
  static const double contentMax = 840;

  /// Geniş ekran mı? (rail düzeni eşiği)
  static bool isWide(double width) => width >= wide;
}

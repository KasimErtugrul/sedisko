import 'package:get/get.dart';

/// GetX 4.x gezinme uyumluluk katmanı.
///
/// GetX 4.x'te `Get.back()`, açık bir snackbar varsa onu kapatıp ROTA
/// POP ETMEDEN döner (get 4.7 `extension_navigation.dart`):
/// ```dart
/// if (isSnackbarOpen && !closeOverlays) {
///   closeCurrentSnackbar();
///   return;
/// }
/// ```
/// Bu uyumluluk kodu, sayfa/sheet/diyalog pop'larını bir bildirim
/// "yuttuğunda" tuhaf gezinme hataları oluşur.
///
/// Snackbar'lar navigator route'ları DEĞİL root overlay girişleri
/// olduğundan, navigator'un kendi pop'u bildirimlerden tamamen
/// etkilenmez. Bu yüzden bu yardımcı navigator'u doğrudan pop'lar;
/// açık bildirime dokunmaz (bildirim kendi 3 sn'lik zamanlayıcısıyla
/// kaybolur; GetX'in closeCurrentSnackbar'ı ise bildirim tam
/// ömrünü tamamladıysa "disposed snackbar" assertion'ıyla patladığı
/// için çağrılmaz).
///
/// Giderilen hata (kullanıcı raporu): "Barkod tara → Open Library'de
/// bulunamadı" bildirimi hâlâ açıkken kullanıcı hızlıca ana sayfaya dönüp
/// "Manuel ekle"ye basarsa, alt sheet'i kapatması gereken `Get.back()`
/// bildirimi kapatır ve sheet AÇIK KALIR; form bu sheet'in üstüne biner.
/// Kaydet deyince form kapanır ama altındaki sheet ana sayfada açık kalır;
/// kullanıcı "okey tikiyle kaydedince ana sayfaya atıyor" algılar. Her
/// seferinde değil, yalnız bildirim ilk saniyelerindeyken olur.
class AppNav {
  const AppNav._();

  /// En üstteki navigator rotasını (sayfa, alt sheet ya da diyalog) pop'lar
  /// ve [result] ile döner. Pop edilecek rota yoksa güvenli no-op'tur.
  ///
  /// NOT: `Get.back()` KULLANMAYIN — snackbar açıkken pop yapmaz. Bu
  /// yardımcı, açık bir bildirim olsa bile pop'u garanti eder.
  static void pop<T>([T? result]) {
    final navigator = Get.key.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop<T>(result);
    }
  }
}

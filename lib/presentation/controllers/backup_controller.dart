import 'package:get/get.dart';

import '../../data/models/backup_model.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/backup_transfer.dart';
import '../controllers/library_controller.dart';
import '../controllers/loan_controller.dart';
import '../controllers/shelf_organize_controller.dart';
import '../controllers/wishlist_controller.dart';
import '../widgets/backup/import_mode_dialog.dart';

/// Yedekleme ve aktarım denetleyicisi.
///
/// WhatsApp senaryosu iki yönde çalışır:
/// 1. **Paylaş**: tüm kitaplık tek JSON dosyasına yazılır, sistem paylaşım
///    menüsü açılır (WhatsApp dahil). Dosya geçici klasörde üretilir.
/// 2. **İçe aktar**: kullanıcı WhatsApp'tan indirdiği dosyayı seçer;
///    dosya uçtan uca doğrulanır, sonra kullanıcı "Birleştir" ya da
///    "Üzerine yaz" kipini seçer ve veri depoya yazılır. Yazma başarılı
///    olursa bellekteki kitap/raf listeleri yeniden okunur.
class BackupController extends GetxController {
  BackupController({
    required BackupService service,
    required BackupSharer sharer,
    required BackupFilePicker filePicker,
    required BackupFileSink fileSink,
    void Function(String title, String message)? onNotify,
  })  : _service = service,
        _sharer = sharer,
        _filePicker = filePicker,
        _fileSink = fileSink,
        _notify = onNotify ?? _defaultNotify;

  final BackupService _service;
  final BackupSharer _sharer;
  final BackupFilePicker _filePicker;
  final BackupFileSink _fileSink;

  /// Bildirimler tek noktadan çıkar; testlerde [_defaultNotify] yerine
  /// sessiz bir alıcı verilir (GetX snackbar widget ağacı ister).
  final void Function(String title, String message) _notify;

  static void _defaultNotify(String title, String message) {
    Get.snackbar(title, message);
  }

  /// Paylaşım/içe aktarma sürerken düğmeler döner ve çift tıklama engellenir.
  final isBusy = false.obs;

  /// Paylaşılacak dosyanın adı: `kitapligim_yedek_2026-11-19_1430.json`.
  static String fileNameFor(DateTime time) =>
      BackupFileNames.forDateTime(time);

  // ---------- Paylaş ----------

  /// Yedeği dosyaya yazıp paylaşım menüsünü açar. Kitaplık boşsa işlem
  /// yapılmaz: boş dosya paylaşmak alıcıyı yanıltır.
  Future<void> exportAndShare() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final envelope = _service.buildEnvelope();
      if (envelope.books.isEmpty && envelope.shelves.isEmpty) {
        _notify(
          'Kitaplık boş',
          'Paylaşılacak kitap ya da raf yok. Önce kitap ekleyin.',
        );
        return;
      }

      final path = await _fileSink.write(envelope.encode());
      await _sharer.shareFile(
        path,
        'Kitaplığım yedeği '
            '(${envelope.books.length} kitap, ${envelope.shelves.length} raf)',
      );
    } catch (error) {
      _notify(
        'Hata',
        'Yedek dosyası oluşturulamadı. Depolama alanını kontrol edin.',
      );
    } finally {
      isBusy.value = false;
    }
  }

  // ---------- İçe aktar ----------

  /// Dosya seçme → doğrulama → kip seçme → uygulama akışını yürütür.
  /// Dosya seçimi ve içeriğinin okunması [_filePicker]'ın işidir;
  /// denetleyici yalnızca metinle çalışır.
  Future<void> pickBackupFile() async {
    if (isBusy.value) return;
    isBusy.value = true;
    try {
      final picked = await _filePicker.pickJsonFile();
      if (picked == null) return; // kullanıcı vazgeçti

      final result = BackupEnvelope.parse(picked.content);
      final envelope = result.envelope;
      if (envelope == null) {
        _notify('Dosya geçersiz', result.error ?? '');
        return;
      }

      final mode = await Get.dialog<BackupImportMode>(
        BackupImportModeDialog(envelope: envelope),
      );
      if (mode == null) return; // kullanıcı vazgeçti

      // Meşgul bayrağı zaten tutuluyor; kilitlenmesiz dahili akış çalışır.
      await _applyImport(envelope, mode);
    } catch (error) {
      _notify('Hata', 'Dosya okunamadı ya da içe aktarma tamamlanamadı.');
    } finally {
      isBusy.value = false;
    }
  }

  /// Doğrulanmış zarfı seçilen kiple uygular; sonrasındaki ekran yenileme
  /// ve özet bildirimini yapar. Testler bu metodu doğrudan çağırabilir.
  Future<BackupImportSummary?> applyImport(
    BackupEnvelope envelope,
    BackupImportMode mode,
  ) async {
    if (isBusy.value) return null;
    isBusy.value = true;
    try {
      return await _applyImport(envelope, mode);
    } finally {
      isBusy.value = false;
    }
  }

  /// Meşgul bayrağını YÖNETMEDEN içe aktarmayı çalıştırır; hem dışa açık
  /// [applyImport] hem de seçme akışı buradan yürür.
  Future<BackupImportSummary?> _applyImport(
    BackupEnvelope envelope,
    BackupImportMode mode,
  ) async {
    try {
      final summary = await _service.applyImport(envelope, mode);
      await _refreshAfterImport();
      _notify('İçe aktarma tamamlandı', _successMessage(summary));
      return summary;
    } catch (error) {
      _notify(
        'Hata',
        'İçe aktarma yazılırken başarısız oldu. Veriniz değişmedi.',
      );
      return null;
    }
  }

  /// Depoya yazılan veriyi bellekteki listelere de yansıtır.
  Future<void> _refreshAfterImport() async {
    if (Get.isRegistered<LibraryController>()) {
      await Get.find<LibraryController>().loadBooks();
    }
    if (Get.isRegistered<ShelfOrganizeController>()) {
      Get.find<ShelfOrganizeController>().reloadFromStore();
    }
    // Ödünç ve satın alma listeleri de yedeğe girdiği için içe aktarma
    // sonrası bellek tazelenir (1.18.0).
    if (Get.isRegistered<LoanController>()) {
      await Get.find<LoanController>().load();
    }
    if (Get.isRegistered<WishlistController>()) {
      await Get.find<WishlistController>().load();
    }
  }

  String _successMessage(BackupImportSummary summary) {
    if (summary.mode == BackupImportMode.replace) {
      final buffer = StringBuffer('${summary.booksImported} kitap ve '
          '${summary.shelvesImported} raf yedekten geri yüklendi.');
      _appendExtras(summary, buffer);
      if (summary.planCleared) buffer.write(' Eski taşıma planı sıfırlandı.');
      return buffer.toString();
    }
    final buffer = StringBuffer('${summary.booksImported} kitap eklendi');
    if (summary.booksSkipped > 0) {
      buffer.write(', ${summary.booksSkipped} kitap zaten var');
    }
    buffer.write('.');
    if (summary.shelvesImported > 0) {
      buffer.write(' ${summary.shelvesImported} raf eklendi.');
    }
    if (summary.shelvesKept > 0) {
      buffer.write(' ${summary.shelvesKept} raf mevcut tanımla eşleşti.');
    }
    _appendExtras(summary, buffer);
    return buffer.toString();
  }

  /// Ödünç/satın alma kayıtlarının özet cümlesini (sadece sıfırdan farklı
  /// sayı varsa) tamponun sonuna ekler.
  void _appendExtras(BackupImportSummary summary, StringBuffer buffer) {
    if (summary.loansImported > 0) {
      buffer.write(' ${summary.loansImported} ödünç kaydı.');
    }
    if (summary.borrowedImported > 0) {
      buffer.write(' ${summary.borrowedImported} ödünç alınan kitap.');
    }
    if (summary.wishlistImported > 0) {
      buffer.write(' ${summary.wishlistImported} satın alma kaydı.');
    }
  }
}

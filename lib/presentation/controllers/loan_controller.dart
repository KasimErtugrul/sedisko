import 'dart:async';

import 'package:get/get.dart';

import '../../core/errors/app_exceptions.dart';
import '../../data/datasources/loan_local_datasource.dart';
import '../../data/models/book_model.dart';
import '../../data/models/borrowed_book_model.dart';
import '../../data/models/loan_model.dart';
import '../../data/services/reading_reminder_service.dart';

/// Ödünç verme ve ödünç alma kayıtlarının GetX denetleyicisi (1.18.0).
///
/// İki bağımsız liste tutar:
/// - [loans]: kitaplıkta verdiğimiz kitapların ödünç kayıtları.
/// - [borrowed]: başkasından aldığımız kitaplar (kitaplık kaydı değil).
///
/// Keşke 34/35 (1.26.0): kayda isteğe bağlı hatırlatma günü eklendi —
/// verilen ödünçte 'iade günü', alınan ödünçte 'sahibine geri ver'
/// bildirimi kurulur ([ReminderScheduler.scheduleOnce]; zamanlayıcı
/// verilmezse — izole testler — hatırlatma sessizce atlanır). Kayıt geri
/// alınınca, silinince ya da hatırlatma temizlenince planlı bildirim de
/// iptal edilir; uygulama açılışında gelecek tarihli hatırlatmalar yeniden
/// kurulur (cihaz yeniden başladığında alarm sıfırlanmış olabilir).
///
/// [onNotify] test edilebilirlik için verilir; verilmezse GetX snackbar
/// gösterilir. Kullanıcıya hata yalnızca depolama yazmalarında gösterilir;
/// boş girdiler sessizce reddedilir (false döner).
class LoanController extends GetxController {
  LoanController({
    required LoanLocalDataSource store,
    ReminderScheduler? reminderScheduler,
    void Function(String title, String message)? onNotify,
  })  : _store = store,
        _scheduler = reminderScheduler,
        _notify = onNotify ?? _defaultNotify;

  final LoanLocalDataSource _store;
  final ReminderScheduler? _scheduler;

  final void Function(String title, String message) _notify;

  final loans = <LoanModel>[].obs;
  final borrowed = <BorrowedBookModel>[].obs;

  static void _defaultNotify(String title, String message) {
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Depodaki tüm kayıtları belleğe yükler. Okuma savunmacıdır (bozuk
  /// blok/kayıt zaten depoda düşürülür); burada ekstra hata işleme gerekmez.
  /// Keşke 34/35 (1.26.0): gelecek tarihli hatırlatmalar açılışta yeniden
  /// kurulur — cihaz yeniden başladığında planlı alarm sıfırlanmış olur.
  Future<void> load() async {
    loans.assignAll(_store.getLoans());
    borrowed.assignAll(_store.getBorrowed());
    _rescheduleReminders();
  }

  /// Sürüyor olan ödünçler; verilme tarihi AZALAN (en yeni önce).
  /// Eşit tarihte son eklenen önce gösterilir (bkz. [_sortedNewestFirst]).
  List<LoanModel> get activeLoans =>
      _sortedNewestFirst(loans.where((l) => l.isActive), (l) => l.lentAt);

  /// Geri alınan ödünçler; dönüş tarihi azalan (en yeni önce).
  List<LoanModel> get returnedLoans =>
      _sortedNewestFirst(loans.where((l) => !l.isActive), _returnedAt);

  /// Sürüyor olan alıntılar; alım tarihi AZALAN (en yeni önce).
  List<BorrowedBookModel> get activeBorrowed => _sortedNewestFirst(
      borrowed.where((b) => b.isActive), (b) => b.borrowedAt);

  /// Geri verilen alıntılar; dönüş tarihi azalan (en yeni önce).
  List<BorrowedBookModel> get returnedBorrowed =>
      _sortedNewestFirst(borrowed.where((b) => !b.isActive), _borrowedReturnedAt);

  /// Kitabın sürüyor olan ödünç kaydı; yoksa `null`.
  /// Rx listesi üzerinde çalıştığından Obx içindeki çağrılar (banner,
  /// aksiyon görünürlüğü) ödünç değişimlerinde yeniden kurulum tetikler.
  LoanModel? activeLoanFor(String bookId) {
    for (final loan in loans) {
      if (loan.bookId == bookId && loan.isActive) return loan;
    }
    return null;
  }

  /// Kitabı [person] kişisine ödünç verir. Aynı kitaba sürüyor bir ödünç
  /// varken yeni kayıt açmak serbesttir; kayıtlar bağımsızdır (önceki
  /// kayıt otomatik geri alınmış sayılmaz).
  ///
  /// [dueAt] verilirse (keşke 34, 1.26.0) o gün için iade hatırlatması
  /// kurulur; kurulum başarısızsa kayıt yine de geçerlidir, kullanıcıya
  /// 'hatırlatma kurulamadı' haberilir (iznin yarısı eksikse kaydın
  /// kendisini düşürmemek bilinçli bir tercihtir).
  Future<bool> lendBook(
    BookModel book,
    String person, {
    String? note,
    DateTime? dueAt,
  }) async {
    final cleanedPerson = person.trim();
    if (cleanedPerson.isEmpty) return false;

    final loan = LoanModel(
      id: LoanModel.newId(),
      bookId: book.id,
      bookTitle: book.title,
      person: cleanedPerson,
      note: _cleanNote(note),
      lentAt: DateTime.now(),
      dueAt: _cleanDate(dueAt),
    );
    final ok = await _saveLoan(loan, isNew: true);
    if (ok) await _scheduleLoanReminder(loan, isNew: true);
    return ok;
  }

  /// Ödünç kaydını geri alınmış işaretler (bugün). Zaten geri alınmışsa
  /// sessizce başarılı sayılır (idempotent). İade hatırlatması (varsa)
  /// iptal edilir: kitap geldi, alarm çalmaya gerek yok.
  Future<bool> markReturned(String loanId) async {
    final index = loans.indexWhere((l) => l.id == loanId);
    if (index < 0) return false;

    final current = loans[index];
    if (!current.isActive) return true;

    final updated = current.copyWith(returnedAt: DateTime.now());
    final ok = await _saveLoan(updated, index: index);
    if (ok) _cancelReminder(current.id);
    return ok;
  }

  Future<bool> removeLoan(String id) async {
    try {
      await _store.removeLoan(id);
    } on StorageException catch (error) {
      _notify('Silinemedi', error.message);
      return false;
    } catch (_) {
      _notify('Silinemedi', 'Beklenmeyen bir sorun oluştu. İşlemi yeniden dene; sürerse uygulamayı kapatıp aç.');
      return false;
    }
    loans.removeWhere((l) => l.id == id);
    _cancelReminder(id);
    return true;
  }

  /// Başkasından ödünç alınan kitabı kaydeder. Yazarlar virgüllü düz
  /// metin değil, zaten ayrılmış liste olarak gelir (diyalog ayırır).
  /// [remindAt] verilirse (keşke 35, 1.26.0) 'sahibine geri ver'
  /// hatırlatması kurulur.
  Future<bool> addBorrowed({
    required String title,
    List<String> authors = const [],
    required String owner,
    String? note,
    DateTime? remindAt,
  }) async {
    final cleanedTitle = title.trim();
    final cleanedOwner = owner.trim();
    if (cleanedTitle.isEmpty || cleanedOwner.isEmpty) return false;

    final item = BorrowedBookModel(
      id: BorrowedBookModel.newId(),
      title: cleanedTitle,
      authors: _cleanAuthors(authors),
      owner: cleanedOwner,
      note: _cleanNote(note),
      borrowedAt: DateTime.now(),
      remindAt: _cleanDate(remindAt),
    );
    final ok = await _saveBorrowed(item, isNew: true);
    if (ok) await _scheduleBorrowedReminder(item, isNew: true);
    return ok;
  }

  /// Mevcut alıntı kaydını günceller (başlık/sahip boşsa reddedilir).
  /// Hatırlatma günü değişmişse bildirim yeniden kurulur; temizlenmişse
  /// iptal edilir.
  Future<bool> updateBorrowed(BorrowedBookModel item) async {
    final index = borrowed.indexWhere((b) => b.id == item.id);
    if (index < 0) return false;
    if (item.title.trim().isEmpty || item.owner.trim().isEmpty) return false;

    final ok = await _saveBorrowed(item, index: index);
    if (ok) _scheduleBorrowedReminder(item, isNew: false);
    return ok;
  }

  /// Alıntıyı geri verildi işaretler (bugün). Zaten geri verilmişse
  /// sessizce başarılı sayılır (idempotent). 'Geri vereyim' hatırlatması
  /// (varsa) iptal edilir.
  Future<bool> markBorrowedReturned(String id) async {
    final index = borrowed.indexWhere((b) => b.id == id);
    if (index < 0) return false;

    final current = borrowed[index];
    if (!current.isActive) return true;

    final ok = await _saveBorrowed(
        current.copyWith(returnedAt: DateTime.now()), index: index);
    if (ok) _cancelReminder(current.id);
    return ok;
  }

  Future<bool> removeBorrowed(String id) async {
    try {
      await _store.removeBorrowed(id);
    } on StorageException catch (error) {
      _notify('Silinemedi', error.message);
      return false;
    } catch (_) {
      _notify('Silinemedi', 'Beklenmeyen bir sorun oluştu. İşlemi yeniden dene; sürerse uygulamayı kapatıp aç.');
      return false;
    }
    borrowed.removeWhere((b) => b.id == id);
    _cancelReminder(id);
    return true;
  }

  // ---------- iç yardımcılar ----------

  // Keşke 34/35 (1.26.0): hatırlatma zamanlaması. Zamanlayıcı verilmediyse
  // (izole testler, denetleyicisiz kurulumlar) tüm bu akış sessizce atlanır;
  // kayıt yazma davranışı hiç değişmez.

  /// Planlı bildirim kimliği: kayıt kimliğinden türetilir. Kayıt kimlikleri
  /// benzersizdir; aynı kayıt her kurulumda AYNI kimliği alır, böylece
  /// yeniden kurulum eski alarmı değiştirir, geri alma/silme tam doğru
  /// alarmı iptal eder.
  static int reminderId(String recordId) => recordId.hashCode & 0x7FFFFFFF;

  static String _loanReminderBody(LoanModel loan) =>
      '"${loan.bookTitle}" kitabını bugün ${loan.person} kişiden geri '
      'isteyebilirsin.';

  static String _borrowedReminderBody(BorrowedBookModel item) =>
      '"${item.title}" kitabını bugün ${item.owner} kişiye geri verebilirsin.';

  /// Ödünç kaydına hatırlatma kurar: kayıt sürüyor ve gelecek bir gün
  /// seçilmişse tek seferlik bildirim; kurulum başarısızsa kullanıcıya
  /// bildirilir (kayıt zaten yazılmıştır, sessiz kalınmaz).
  Future<void> _scheduleLoanReminder(LoanModel loan,
      {required bool isNew}) async {
    final scheduler = _scheduler;
    if (scheduler == null) return;
    if (!loan.isActive || loan.dueAt == null) {
      // Yeni kayıtta hatırlatma yok: iptal edilecek alarm da yoktur.
      // Düzenlemede gün temizlenmişse eski alarm kapatılır.
      if (!isNew) unawaited(scheduler.cancel(reminderId(loan.id)));
      return;
    }
    _scheduleOnceGuarded(
      schedule: () => scheduler.scheduleOnce(
        id: reminderId(loan.id),
        title: 'İade günü',
        body: _loanReminderBody(loan),
        at: loan.dueAt!,
      ),
      isNew: isNew,
    );
  }

  /// Alıntı kaydına 'sahibine geri ver' hatırlatması kurar; gün
  /// temizlenmişse ya da kitap geri verilmişse alarmı iptal eder.
  Future<void> _scheduleBorrowedReminder(BorrowedBookModel item,
      {required bool isNew}) async {
    final scheduler = _scheduler;
    if (scheduler == null) return;
    if (!item.isActive || item.remindAt == null) {
      // Yeni kayıtta hatırlatma yok: iptal edilecek alarm da yoktur.
      // Düzenlemede gün temizlenmişse eski alarm kapatılır.
      if (!isNew) unawaited(scheduler.cancel(reminderId(item.id)));
      return;
    }
    _scheduleOnceGuarded(
      schedule: () => scheduler.scheduleOnce(
        id: reminderId(item.id),
        title: 'Geri verme günü',
        body: _borrowedReminderBody(item),
        at: item.remindAt!,
      ),
      isNew: isNew,
    );
  }

  /// Tek seferlik kurulumu çalıştırır; başarısızlıkta kullanıcıyı
  /// haberdar eder. Yeni kayıtta kurulum hatası ayrı bir haberdir; güncelleme
  /// yeniden kurulumunda sessizlik tercih edilir (kayıt zaten yaşar).
  Future<void> _scheduleOnceGuarded({
    required Future<bool> Function() schedule,
    required bool isNew,
  }) async {
    final ok = await schedule();
    if (!ok && isNew) {
      _notify(
        'Hatırlatma kurulamadı',
        'Kayıt kaydedildi ama bildirim izni yok gibi görünüyor. '
        'Cihaz ayarlarından bildirimlere izin ver.',
      );
    }
  }

  /// Açılış yeniden kurulumu: gelecek tarihli hatırlatmalar yeniden kurulur
  /// (geçmiş tarihleri zamanlayıcı zaten reddeder); hatırlatmasız/geri
  /// verilmiş kayıtların artık alarmları iptal edilir.
  void _rescheduleReminders() {
    final scheduler = _scheduler;
    if (scheduler == null) return;
    for (final loan in loans) {
      if (loan.isActive && loan.dueAt != null) {
        unawaited(scheduler.scheduleOnce(
          id: reminderId(loan.id),
          title: 'İade günü',
          body: _loanReminderBody(loan),
          at: loan.dueAt!,
        ));
      } else {
        unawaited(scheduler.cancel(reminderId(loan.id)));
      }
    }
    for (final item in borrowed) {
      if (item.isActive && item.remindAt != null) {
        unawaited(scheduler.scheduleOnce(
          id: reminderId(item.id),
          title: 'Geri verme günü',
          body: _borrowedReminderBody(item),
          at: item.remindAt!,
        ));
      } else {
        unawaited(scheduler.cancel(reminderId(item.id)));
      }
    }
  }

  void _cancelReminder(String recordId) {
    _scheduler?.cancel(reminderId(recordId));
  }

  /// Hatırlatma tarihi savunmacı temizliği: yalnız geleceğe dünülmüş
  /// (bugün 00:00'dan sonra) tarih kabul edilir; bozuk/ geçmiş tarih
  /// sessizce 'yok' olur.
  static DateTime? _cleanDate(DateTime? value) {
    if (value == null) return null;
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    if (!value.isAfter(dayStart)) return null;
    return value;
  }

  Future<bool> _saveLoan(LoanModel loan, {int? index, bool isNew = false}) async {
    try {
      await _store.upsertLoan(loan);
    } on StorageException catch (error) {
      _notify('Kaydedilemedi', error.message);
      return false;
    } catch (_) {
      _notify('Kaydedilemedi', 'Beklenmeyen bir sorun oluştu. İşlemi yeniden dene; sürerse uygulamayı kapatıp aç.');
      return false;
    }
    if (isNew) {
      loans.add(loan);
    } else if (index != null) {
      loans[index] = loan;
    }
    return true;
  }

  Future<bool> _saveBorrowed(BorrowedBookModel item,
      {int? index, bool isNew = false}) async {
    try {
      await _store.upsertBorrowed(item);
    } on StorageException catch (error) {
      _notify('Kaydedilemedi', error.message);
      return false;
    } catch (_) {
      _notify('Kaydedilemedi', 'Beklenmeyen bir sorun oluştu. İşlemi yeniden dene; sürerse uygulamayı kapatıp aç.');
      return false;
    }
    if (isNew) {
      borrowed.add(item);
    } else if (index != null) {
      borrowed[index] = item;
    }
    return true;
  }

  static DateTime _returnedAt(LoanModel loan) => loan.returnedAt ?? loan.lentAt;

  static DateTime _borrowedReturnedAt(BorrowedBookModel item) =>
      item.returnedAt ?? item.borrowedAt;

  /// Tarihe göre AZALAN sıralı kopya döndürür (en yeni önce).
  ///
  /// Eşitlik kırıcı: tarihler aynıysa listedeki konumu büyük olan (son
  /// eklenen) önce gösterilir. Windows gibi kaba saat çözünürlüğüne
  /// sahip platformlarda art arda eklenen iki kayıt aynı ana denk
  /// gelebilir (~15 ms tık); kırıcı olmadan kararlı sıralama ekleme
  /// sırasını korur ve gösterim platformdan platforma değişirdi.
  static List<T> _sortedNewestFirst<T>(
    Iterable<T> source,
    DateTime Function(T) at,
  ) {
    final entries = source.toList().asMap().entries.toList()
      ..sort((a, b) {
        final byDate = at(b.value).compareTo(at(a.value));
        if (byDate != 0) return byDate;
        return b.key - a.key; // eşitlikte son eklenen önce
      });
    return [for (final entry in entries) entry.value];
  }

  static String? _cleanNote(String? note) {
    final trimmed = note?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static List<String> _cleanAuthors(List<String> raw) {
    final result = <String>[];
    for (final item in raw) {
      final name = item.trim();
      if (name.isNotEmpty) result.add(name);
    }
    return result;
  }
}

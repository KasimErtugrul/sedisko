import 'package:get/get.dart';

import '../../core/errors/app_exceptions.dart';
import '../../data/datasources/loan_local_datasource.dart';
import '../../data/models/book_model.dart';
import '../../data/models/borrowed_book_model.dart';
import '../../data/models/loan_model.dart';

/// Ödünç verme ve ödünç alma kayıtlarının GetX denetleyicisi (1.18.0).
///
/// İki bağımsız liste tutar:
/// - [loans]: kitaplıkta verdiğimiz kitapların ödünç kayıtları.
/// - [borrowed]: başkasından aldığımız kitaplar (kitaplık kaydı değil).
///
/// [onNotify] test edilebilirlik için verilir; verilmezse GetX snackbar
/// gösterilir. Kullanıcıya hata yalnızca depolama yazmalarında gösterilir;
/// boş girdiler sessizce reddedilir (false döner).
class LoanController extends GetxController {
  LoanController({
    required LoanLocalDataSource store,
    void Function(String title, String message)? onNotify,
  })  : _store = store,
        _notify = onNotify ?? _defaultNotify;

  final LoanLocalDataSource _store;

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
  Future<void> load() async {
    loans.assignAll(_store.getLoans());
    borrowed.assignAll(_store.getBorrowed());
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
  Future<bool> lendBook(BookModel book, String person, {String? note}) async {
    final cleanedPerson = person.trim();
    if (cleanedPerson.isEmpty) return false;

    final loan = LoanModel(
      id: LoanModel.newId(),
      bookId: book.id,
      bookTitle: book.title,
      person: cleanedPerson,
      note: _cleanNote(note),
      lentAt: DateTime.now(),
    );
    return _saveLoan(loan, isNew: true);
  }

  /// Ödünç kaydını geri alınmış işaretler (bugün). Zaten geri alınmışsa
  /// sessizce başarılı sayılır (idempotent).
  Future<bool> markReturned(String loanId) async {
    final index = loans.indexWhere((l) => l.id == loanId);
    if (index < 0) return false;

    final current = loans[index];
    if (!current.isActive) return true;

    final updated = current.copyWith(returnedAt: DateTime.now());
    return _saveLoan(updated, index: index);
  }

  Future<bool> removeLoan(String id) async {
    try {
      await _store.removeLoan(id);
    } on StorageException catch (error) {
      _notify('Silinemedi', error.message);
      return false;
    } catch (_) {
      _notify('Silinemedi', 'Beklenmeyen bir sorun oluştu.');
      return false;
    }
    loans.removeWhere((l) => l.id == id);
    return true;
  }

  /// Başkasından ödünç alınan kitabı kaydeder. Yazarlar virgüllü düz
  /// metin değil, zaten ayrılmış liste olarak gelir (diyalog ayırır).
  Future<bool> addBorrowed({
    required String title,
    List<String> authors = const [],
    required String owner,
    String? note,
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
    );
    return _saveBorrowed(item, isNew: true);
  }

  /// Mevcut alıntı kaydını günceller (başlık/sahip boşsa reddedilir).
  Future<bool> updateBorrowed(BorrowedBookModel item) async {
    final index = borrowed.indexWhere((b) => b.id == item.id);
    if (index < 0) return false;
    if (item.title.trim().isEmpty || item.owner.trim().isEmpty) return false;

    return _saveBorrowed(item, index: index);
  }

  /// Alıntıyı geri verildi işaretler (bugün). Zaten geri verilmişse
  /// sessizce başarılı sayılır (idempotent).
  Future<bool> markBorrowedReturned(String id) async {
    final index = borrowed.indexWhere((b) => b.id == id);
    if (index < 0) return false;

    final current = borrowed[index];
    if (!current.isActive) return true;

    return _saveBorrowed(current.copyWith(returnedAt: DateTime.now()),
        index: index);
  }

  Future<bool> removeBorrowed(String id) async {
    try {
      await _store.removeBorrowed(id);
    } on StorageException catch (error) {
      _notify('Silinemedi', error.message);
      return false;
    } catch (_) {
      _notify('Silinemedi', 'Beklenmeyen bir sorun oluştu.');
      return false;
    }
    borrowed.removeWhere((b) => b.id == id);
    return true;
  }

  // ---------- iç yardımcılar ----------

  Future<bool> _saveLoan(LoanModel loan, {int? index, bool isNew = false}) async {
    try {
      await _store.upsertLoan(loan);
    } on StorageException catch (error) {
      _notify('Kaydedilemedi', error.message);
      return false;
    } catch (_) {
      _notify('Kaydedilemedi', 'Beklenmeyen bir sorun oluştu.');
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
      _notify('Kaydedilemedi', 'Beklenmeyen bir sorun oluştu.');
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

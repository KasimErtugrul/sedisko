import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';
import '../../data/models/reading_log_entry.dart';
import '../../domain/repositories/book_repository.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';

class LibraryController extends GetxController {
  /// [onNotify] test edilebilirlik için verilir; verilmezse GetX snackbar
  /// gösterilir.
  LibraryController(
    this._repository, {
    void Function(String title, String message)? onNotify,
  }) : _notify = onNotify ?? _defaultNotify;

  final BookRepository _repository;

  final void Function(String title, String message) _notify;

  final books = <BookModel>[].obs;
  final isLoading = false.obs;
  final isLookingUp = false.obs;
  final query = ''.obs;

  /// Ana sayfadaki arama alanının denetleyicisi (temizle butonu için).
  final searchCtrl = TextEditingController();

  final statusFilter = Rxn<ReadingStatus>();

  static void _defaultNotify(String title, String message) {
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }

  @override
  void onInit() {
    super.onInit();
    loadBooks();
  }

  @override
  void onClose() {
    searchCtrl.dispose();
    super.onClose();
  }

  Future<void> loadBooks() async {
    isLoading.value = true;
    try {
      books.assignAll(await _repository.getBooks());
      _sort();
    } on StorageException catch (error) {
      _notify('Kitaplar yüklenemedi', error.message);
    } catch (_) {
      _notify('Kitaplar yüklenemedi', 'Beklenmeyen bir sorun oluştu.');
    } finally {
      isLoading.value = false;
    }
  }

  // ---------- Sorgular ----------

  /// Türkçe İ/ı eşleşmesini koruyan arama: kitap adı, yazar, raf ve ISBN.
  List<BookModel> get filteredBooks {
    final q = TextNormalizer.searchKey(query.value.trim());
    final status = statusFilter.value;
    return books.where((b) {
      if (status != null && b.status != status) return false;
      if (q.isEmpty) return true;
      return TextNormalizer.searchKey(b.title).contains(q) ||
          TextNormalizer.searchKey(b.authorsText).contains(q) ||
          TextNormalizer.searchKey(b.shelf).contains(q) ||
          TextNormalizer.searchKey(b.isbn ?? '').contains(q);
    }).toList();
  }

  List<String> get shelves {
    final set = books
        .map((b) => b.shelf.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort(TextNormalizer.compareTr);
    return set;
  }

  BookModel? byId(String id) => books.firstWhereOrNull((b) => b.id == id);

  BookModel? findByIsbn(String isbn) {
    final clean = _cleanIsbn(isbn);
    if (clean.isEmpty) return null;
    return books.firstWhereOrNull((b) => _cleanIsbn(b.isbn ?? '') == clean);
  }

  /// [isbn] başka bir kitapta (farklı id) kullanılıyor mu?
  bool hasIsbnConflict(String isbn, {String? exceptId}) {
    final clean = _cleanIsbn(isbn);
    if (clean.isEmpty) return false;
    return books.any(
      (b) => b.id != exceptId && _cleanIsbn(b.isbn ?? '') == clean,
    );
  }

  // ---------- Kayıt işlemleri ----------

  /// Depolama başarılıysa `true` döner; başarısızsa kullanıcıya
  /// açıklama gösterilir ve bellek güncellenmez.
  ///
  /// Okuma günlüğü, eski ve yeni durum arasındaki farktan türetilir:
  /// tüm yazma yolları (form kaydı, hızlı aksiyonlar, ilerleme diyaloğu)
  /// buradan geçtiği için kayıtlar tek merkezde birikir.
  Future<bool> saveBook(BookModel book) async {
    final merged = book.copyWith(
      readingLog: _mergedReadingLog(byId(book.id), book),
    );
    try {
      await _repository.saveBook(merged);
    } on StorageException catch (error) {
      _notify('Kaydedilemedi', error.message);
      return false;
    } catch (_) {
      _notify('Kaydedilemedi', 'Beklenmeyen bir sorun oluştu.');
      return false;
    }

    final index = books.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      books[index] = merged;
    } else {
      books.add(merged);
    }
    _sort();
    return true;
  }

  Future<bool> deleteBook(String id) async {
    try {
      await _repository.deleteBook(id);
    } on StorageException catch (error) {
      _notify('Silinemedi', error.message);
      return false;
    } catch (_) {
      _notify('Silinemedi', 'Beklenmeyen bir sorun oluştu.');
      return false;
    }
    books.removeWhere((b) => b.id == id);
    return true;
  }

  /// Okuma günlüğünü [old] ile [incoming] arasındaki farktan üretir.
  ///
  /// Kurallar:
  /// - "Başlanmadı"ya dönüş ilerleme sıfırlamasıdır; günlük temizlenir.
  /// - Günlük boşsa ilk kayıt referans noktasıdır (o ana kadar okunanlar
  ///   takip başlamadan olduğundan sayılmaz).
  /// - Sayfa artışı ilerleme kaydıdır (tarih: şimdi).
  /// - Bitiş tarihi yeni atandıysa bitiş olayı olarak işaretlenir.
  /// - Konum 0'a döndüyse ("Yeniden oku") yeni turun başlangıcı eklenir.
  /// - Sayfa elle geriye çekildiyse (düzeltme) kayıt eklenmez.
  List<ReadingLogEntry> _mergedReadingLog(BookModel? old, BookModel incoming) {
    if (incoming.status == ReadingStatus.notStarted) {
      return const <ReadingLogEntry>[];
    }

    final log = List<ReadingLogEntry>.of(old?.readingLog ?? const []);
    final now = DateTime.now();

    if (log.isEmpty) {
      log.add(ReadingLogEntry(at: now, page: incoming.currentPage));
      return log;
    }

    final lastPage = log.last.page;
    if (incoming.currentPage > lastPage) {
      log.add(ReadingLogEntry(at: now, page: incoming.currentPage));
    } else if (incoming.status == ReadingStatus.finished &&
        old?.status != ReadingStatus.finished) {
      // Bitmiş durumuna geçiş: sayfa değişmese de olay günlüğe yazılır.
      log.add(
        ReadingLogEntry(
          at: incoming.finishedAt ?? now,
          page: incoming.currentPage,
        ),
      );
    } else if (incoming.currentPage == 0 && lastPage > 0) {
      log.add(ReadingLogEntry(at: now, page: 0));
    }
    return log;
  }

  Future<bool> updateProgress(BookModel book, int page) async {
    final max = book.pageCount > 0 ? book.pageCount : page;
    final p = page.clamp(0, max).toInt();
    final now = DateTime.now();

    var updated = book.copyWith(currentPage: p);
    if (book.pageCount > 0 && p >= book.pageCount) {
      updated = updated.copyWith(
        status: ReadingStatus.finished,
        startedAt: book.startedAt ?? now,
        finishedAt: now,
      );
    } else if (p > 0) {
      updated = updated.copyWith(
        status: ReadingStatus.reading,
        startedAt: book.startedAt ?? now,
        finishedAt: null,
      );
    }
    return saveBook(updated);
  }

  Future<bool> startReading(BookModel book) {
    return saveBook(book.copyWith(
      status: ReadingStatus.reading,
      startedAt: book.startedAt ?? DateTime.now(),
      finishedAt: null,
    ));
  }

  Future<bool> restartReading(BookModel book) {
    return saveBook(book.copyWith(
      status: ReadingStatus.reading,
      currentPage: 0,
      startedAt: DateTime.now(),
      finishedAt: null,
    ));
  }

  Future<bool> markFinished(BookModel book) {
    final now = DateTime.now();
    return saveBook(book.copyWith(
      status: ReadingStatus.finished,
      currentPage: book.pageCount > 0 ? book.pageCount : book.currentPage,
      startedAt: book.startedAt ?? now,
      finishedAt: now,
    ));
  }

  // ---------- Barkod akışı ----------

  Future<void> addByScan() async {
    // Generic'siz çağrı: GetX rotaları GetPageRoute<dynamic> olduğundan
    // Get.toNamed<String> runtime'da Route<String?> cast hatası verir.
    final result = await Get.toNamed(Routes.scanner);
    final code = result is String ? result.trim() : null;
    if (code == null || code.isEmpty) return;
    await handleIsbn(code);
  }

  Future<void> handleIsbn(String isbn) async {
    if (isLookingUp.value) return;

    final existing = findByIsbn(isbn);
    if (existing != null) {
      _notify('Zaten kitaplıkta', '"${existing.title}" daha önce eklenmiş.');
      Get.toNamed(Routes.detail, arguments: existing.id);
      return;
    }

    isLookingUp.value = true;
    try {
      final found = await _repository.fetchBookByIsbn(isbn);
      if (found != null) {
        Get.toNamed(Routes.form, arguments: BookFormArgs(book: found));
      } else {
        _notify(
          'Open Library\'de bulunamadı',
          'Bilgileri elle girebilirsin. ISBN senin için dolduruldu.',
        );
        Get.toNamed(
          Routes.form,
          arguments: BookFormArgs(book: BookModel.blank(isbn: isbn)),
        );
      }
    } on NetworkException catch (error) {
      _notify(
        'Bağlantı sorunu',
        '${error.message}. Bilgileri elle girebilirsin.',
      );
      Get.toNamed(
        Routes.form,
        arguments: BookFormArgs(book: BookModel.blank(isbn: isbn)),
      );
    } finally {
      isLookingUp.value = false;
    }
  }

  // ---------- Yardımcılar ----------

  /// Raf boş olanlar sonda, dolu olanlar Türkçe alfabe sırasıyla.
  void _sort() {
    books.sort((a, b) {
      final rankA = a.shelf.trim().isEmpty ? 1 : 0;
      final rankB = b.shelf.trim().isEmpty ? 1 : 0;
      if (rankA != rankB) return rankA.compareTo(rankB);
      final shelfCompare =
          TextNormalizer.compareTr(a.shelf.trim(), b.shelf.trim());
      if (shelfCompare != 0) return shelfCompare;
      return TextNormalizer.compareTr(a.title, b.title);
    });
  }

  String _cleanIsbn(String isbn) => isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');
}

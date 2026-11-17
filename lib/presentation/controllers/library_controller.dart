import 'package:get/get.dart';

import '../../core/errors/app_exceptions.dart';
import '../../data/models/book_model.dart';
import '../../domain/repositories/book_repository.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';

class LibraryController extends GetxController {
  LibraryController(this._repository);

  final BookRepository _repository;

  final books = <BookModel>[].obs;
  final isLoading = false.obs;
  final isLookingUp = false.obs;
  final query = ''.obs;
  final statusFilter = Rxn<ReadingStatus>();

  @override
  void onInit() {
    super.onInit();
    loadBooks();
  }

  Future<void> loadBooks() async {
    isLoading.value = true;
    try {
      books.assignAll(await _repository.getBooks());
      _sort();
    } finally {
      isLoading.value = false;
    }
  }

  // ---------- Sorgular ----------

  List<BookModel> get filteredBooks {
    final q = query.value.trim().toLowerCase();
    final status = statusFilter.value;
    return books.where((b) {
      if (status != null && b.status != status) return false;
      if (q.isEmpty) return true;
      return b.title.toLowerCase().contains(q) ||
          b.authorsText.toLowerCase().contains(q) ||
          b.shelf.toLowerCase().contains(q);
    }).toList();
  }

  List<String> get shelves {
    final set = books
        .map((b) => b.shelf.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return set;
  }

  BookModel? byId(String id) => books.firstWhereOrNull((b) => b.id == id);

  BookModel? findByIsbn(String isbn) {
    final clean = _cleanIsbn(isbn);
    if (clean.isEmpty) return null;
    return books.firstWhereOrNull((b) => _cleanIsbn(b.isbn ?? '') == clean);
  }

  // ---------- Kayıt işlemleri ----------

  Future<void> saveBook(BookModel book) async {
    await _repository.saveBook(book);
    final index = books.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      books[index] = book;
    } else {
      books.add(book);
    }
    _sort();
  }

  Future<void> deleteBook(String id) async {
    await _repository.deleteBook(id);
    books.removeWhere((b) => b.id == id);
  }

  Future<void> updateProgress(BookModel book, int page) async {
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
    await saveBook(updated);
  }

  Future<void> startReading(BookModel book) {
    return saveBook(book.copyWith(
      status: ReadingStatus.reading,
      startedAt: book.startedAt ?? DateTime.now(),
      finishedAt: null,
    ));
  }

  Future<void> restartReading(BookModel book) {
    return saveBook(book.copyWith(
      status: ReadingStatus.reading,
      currentPage: 0,
      startedAt: DateTime.now(),
      finishedAt: null,
    ));
  }

  Future<void> markFinished(BookModel book) {
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
    final code = await Get.toNamed<String>(Routes.scanner);
    if (code == null || code.isEmpty) return;
    await handleIsbn(code);
  }

  Future<void> handleIsbn(String isbn) async {
    final existing = findByIsbn(isbn);
    if (existing != null) {
      _toast('Zaten kitaplıkta', '"${existing.title}" daha önce eklenmiş.');
      Get.toNamed(Routes.detail, arguments: existing.id);
      return;
    }

    isLookingUp.value = true;
    try {
      final found = await _repository.fetchBookByIsbn(isbn);
      if (found != null) {
        Get.toNamed(Routes.form, arguments: BookFormArgs(book: found));
      } else {
        _toast('Open Library\'de bulunamadı',
            'Bilgileri elle girebilirsin. ISBN senin için dolduruldu.');
        Get.toNamed(Routes.form,
            arguments: BookFormArgs(book: BookModel.blank(isbn: isbn)));
      }
    } on NetworkException catch (e) {
      _toast('Bağlantı sorunu', '${e.message}. Bilgileri elle girebilirsin.');
      Get.toNamed(Routes.form,
          arguments: BookFormArgs(book: BookModel.blank(isbn: isbn)));
    } finally {
      isLookingUp.value = false;
    }
  }

  // ---------- Yardımcılar ----------

  void _sort() {
    books.sort((a, b) {
      final shelfCompare = a.shelf.toLowerCase().compareTo(b.shelf.toLowerCase());
      if (shelfCompare != 0) return shelfCompare;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }

  String _cleanIsbn(String isbn) => isbn.replaceAll(RegExp(r'[^0-9Xx]'), '');

  void _toast(String title, String message) {
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }
}

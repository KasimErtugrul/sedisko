import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exceptions.dart';
import '../../data/models/book_model.dart';
import '../../domain/repositories/book_repository.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import 'library_controller.dart';

class BookFormController extends GetxController {
  BookFormController(this._repository, this._library);

  final BookRepository _repository;
  final LibraryController _library;

  final formKey = GlobalKey<FormState>();

  final titleCtrl = TextEditingController();
  final authorsCtrl = TextEditingController();
  final isbnCtrl = TextEditingController();
  final pagesCtrl = TextEditingController();
  final publisherCtrl = TextEditingController();
  final publishDateCtrl = TextEditingController();
  final shelfCtrl = TextEditingController();
  final currentPageCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  final status = ReadingStatus.notStarted.obs;
  final startedAt = Rxn<DateTime>();
  final finishedAt = Rxn<DateTime>();
  final coverUrl = RxnString();
  final isFetching = false.obs;

  late final bool isEdit;
  late final String _id;
  late final DateTime _addedAt;
  late bool _isManual;

  List<String> get shelves => _library.shelves;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    final formArgs = args is BookFormArgs ? args : const BookFormArgs();
    final book = formArgs.book ?? BookModel.blank();

    isEdit = formArgs.isEdit;
    _id = book.id;
    _addedAt = book.addedAt;
    _isManual = book.isManual;

    titleCtrl.text = book.title;
    authorsCtrl.text = book.authorsText;
    isbnCtrl.text = book.isbn ?? '';
    pagesCtrl.text = book.pageCount > 0 ? '${book.pageCount}' : '';
    publisherCtrl.text = book.publisher ?? '';
    publishDateCtrl.text = book.publishDate ?? '';
    shelfCtrl.text = book.shelf;
    currentPageCtrl.text = '${book.currentPage}';
    notesCtrl.text = book.notes ?? '';

    status.value = book.status;
    startedAt.value = book.startedAt;
    finishedAt.value = book.finishedAt;
    coverUrl.value = book.coverUrl;
  }

  // ---------- Open Library / Barkod ----------

  Future<void> fetchFromOpenLibrary() async {
    final isbn = isbnCtrl.text.trim();
    if (isbn.isEmpty) {
      _toast('ISBN gerekli', 'Önce ISBN yaz ya da barkodu tara.');
      return;
    }

    isFetching.value = true;
    try {
      final found = await _repository.fetchBookByIsbn(isbn);
      if (found == null) {
        _toast('Bulunamadı',
            "Open Library'de kayıt yok. Bilgileri elle girebilirsin.");
        return;
      }
      _fillIfNotEmpty(titleCtrl, found.title);
      _fillIfNotEmpty(authorsCtrl, found.authorsText);
      _fillIfNotEmpty(publisherCtrl, found.publisher ?? '');
      _fillIfNotEmpty(publishDateCtrl, found.publishDate ?? '');
      if (found.pageCount > 0) pagesCtrl.text = '${found.pageCount}';
      if (found.coverUrl != null) coverUrl.value = found.coverUrl;
      _isManual = false;
      _toast('Bilgiler getirildi', found.title);
    } on NetworkException catch (e) {
      _toast('Bağlantı sorunu', e.message);
    } finally {
      isFetching.value = false;
    }
  }

  Future<void> scanIsbn() async {
    final code = await Get.toNamed<String>(Routes.scanner);
    if (code == null || code.isEmpty) return;
    isbnCtrl.text = code;
    await fetchFromOpenLibrary();
  }

  // ---------- Okuma durumu ----------

  void setStatus(ReadingStatus newStatus) {
    status.value = newStatus;
    final now = DateTime.now();
    switch (newStatus) {
      case ReadingStatus.notStarted:
        startedAt.value = null;
        finishedAt.value = null;
        currentPageCtrl.text = '0';
        break;
      case ReadingStatus.reading:
        startedAt.value ??= now;
        finishedAt.value = null;
        break;
      case ReadingStatus.finished:
        startedAt.value ??= now;
        finishedAt.value ??= now;
        final pages = int.tryParse(pagesCtrl.text.trim()) ?? 0;
        if (pages > 0) currentPageCtrl.text = '$pages';
        break;
    }
  }

  Future<void> pickDate(BuildContext context, Rxn<DateTime> target) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: target.value ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) target.value = picked;
  }

  // ---------- Kaydet ----------

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final pages = int.tryParse(pagesCtrl.text.trim()) ?? 0;
    var current = int.tryParse(currentPageCtrl.text.trim()) ?? 0;
    final s = status.value;
    if (s == ReadingStatus.notStarted) current = 0;
    if (s == ReadingStatus.finished && pages > 0) current = pages;

    final book = BookModel(
      id: _id,
      title: titleCtrl.text.trim(),
      authors: authorsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      isbn: _nullIfEmpty(isbnCtrl.text),
      coverUrl: coverUrl.value,
      publisher: _nullIfEmpty(publisherCtrl.text),
      publishDate: _nullIfEmpty(publishDateCtrl.text),
      pageCount: pages,
      shelf: shelfCtrl.text.trim(),
      status: s,
      currentPage: current,
      startedAt: s == ReadingStatus.notStarted ? null : startedAt.value,
      finishedAt: s == ReadingStatus.finished ? finishedAt.value : null,
      notes: _nullIfEmpty(notesCtrl.text),
      isManual: _isManual,
      addedAt: _addedAt,
    );

    await _library.saveBook(book);
    Get.back();
    Get.snackbar('Kaydedildi', book.title, snackPosition: SnackPosition.BOTTOM);
  }

  // ---------- Yardımcılar ----------

  void _fillIfNotEmpty(TextEditingController c, String value) {
    if (value.trim().isNotEmpty) c.text = value;
  }

  String? _nullIfEmpty(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  void _toast(String title, String message) {
    Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    authorsCtrl.dispose();
    isbnCtrl.dispose();
    pagesCtrl.dispose();
    publisherCtrl.dispose();
    publishDateCtrl.dispose();
    shelfCtrl.dispose();
    currentPageCtrl.dispose();
    notesCtrl.dispose();
    super.onClose();
  }
}

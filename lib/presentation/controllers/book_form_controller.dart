import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/isbn_validator.dart';
import '../../data/models/book_model.dart';
import '../../data/services/book_photo_picker.dart';
import '../../data/services/cover_photo_store.dart';
import '../../domain/repositories/book_repository.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../utils/app_navigation.dart';
import 'library_controller.dart';

class BookFormController extends GetxController {
  /// [photoStore]/[photoPicker] test edilebilirlik için verilir;
  /// verilmezse gerçek gerçekleştirmeler kullanılır.
  BookFormController(
    this._repository,
    this._library, {
    CoverPhotoStore? photoStore,
    BookPhotoPicker? photoPicker,
  })  : _photoStore = photoStore ?? CoverPhotoStore(),
        _photoPicker = photoPicker ?? ImagePickerBookPhotoPicker();

  final BookRepository _repository;
  final LibraryController _library;
  final CoverPhotoStore _photoStore;
  final BookPhotoPicker _photoPicker;

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

  /// Bitirme hedefi: kitabı hangi tarihe kadar bitirmek istiyorsun.
  /// İsteğe bağlıdır; kayıtta [BookModel.targetFinishDate]'e yazılır.
  final targetFinishDate = Rxn<DateTime>();

  final coverUrl = RxnString();

  /// Çekilen/seçilen kitap fotoğrafının kalıcı yolu; kayıtta
  /// [BookModel.coverPath]'e yazılır.
  final coverPath = Rxn<String>();

  /// Fotoğraf kopyalanırken kısa bir bekleme göstergesi için.
  final isPhotoBusy = false.obs;

  final isFavorite = false.obs;
  final isFetching = false.obs;
  final isSaving = false.obs;

  /// Formda kaydedilmemiş giriş var mı? Kullanıcı yazmaya başladıysa
  /// geri tuşu onay diyaloğu sorar (1.16.0, kullanıcı isteği).
  final isDirty = false.obs;

  late final bool isEdit;
  late final String _id;
  late final DateTime _addedAt;
  late bool _isManual;

  /// Form açıldığında kitabın kayıtlı fotoğrafı. Kaydetme başarılı olursa
  /// artık referans edilmeyen eski dosya diskten silinir.
  late final String? _originalCoverPath;

  /// Açılış anındaki form görüntüsü; [isDirty] bu anlık görüntüyle
  /// karşılaştırılarak hesaplanır.
  final _initialTexts = <TextEditingController, String>{};
  late ReadingStatus _initialStatus;
  late DateTime? _initialStartedAt;
  late DateTime? _initialFinishedAt;
  late DateTime? _initialTargetDate;
  late String? _initialCoverUrl;
  late String? _initialCoverPath;
  late bool _initialFavorite;

  /// Metin alanı dinleyicileri; [onClose]'da ayrılır.
  final List<VoidCallback> _textListeners = [];

  /// Rx değişikliklerini izleyen GetX işçileri; [onClose]'da kapatılır.
  final List<Worker> _workers = [];

  List<String> get shelves => _library.shelves;

  /// Yazar önerisi havuzu: kitaplıkta daha önce geçmiş yazar adları
  /// (görünen adlar, Türkçe sıralı). Otomatik tamamlama alanı besler
  /// (1.16.0, kullanıcı isteği: "yazmaya başlayınca çıksın, zaman kazanır").
  List<String> get authorSuggestions => _library.authors;

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
    targetFinishDate.value = book.targetFinishDate;
    coverUrl.value = book.coverUrl;
    coverPath.value = book.coverPath;
    _originalCoverPath = book.coverPath;
    isFavorite.value = book.isFavorite;

    _captureInitialState();
    _watchChanges();
    _refreshDirty();
  }

  /// Açılış görüntüsünü yakalar: tüm metin alanları + durum/tarih/fotoğraf
  /// ve favori seçimi. Karşılaştırma bunlara karşı yapılır.
  void _captureInitialState() {
    for (final ctrl in _textControllers) {
      _initialTexts[ctrl] = ctrl.text;
    }
    _initialStatus = status.value;
    _initialStartedAt = startedAt.value;
    _initialFinishedAt = finishedAt.value;
    _initialTargetDate = targetFinishDate.value;
    _initialCoverUrl = coverUrl.value;
    _initialCoverPath = coverPath.value;
    _initialFavorite = isFavorite.value;
  }

  List<TextEditingController> get _textControllers => [
        titleCtrl,
        authorsCtrl,
        isbnCtrl,
        pagesCtrl,
        publisherCtrl,
        publishDateCtrl,
        shelfCtrl,
        currentPageCtrl,
        notesCtrl,
      ];

  /// Her metin ve Rx değişikliğinde kirli durumunu yeniden hesaplar.
  void _watchChanges() {
    for (final ctrl in _textControllers) {
      final listener = _refreshDirty;
      ctrl.addListener(listener);
      _textListeners.add(listener);
    }
    _workers.addAll([
      ever(status, (_) => _refreshDirty()),
      ever(startedAt, (_) => _refreshDirty()),
      ever(finishedAt, (_) => _refreshDirty()),
      ever(targetFinishDate, (_) => _refreshDirty()),
      ever(coverUrl, (_) => _refreshDirty()),
      ever(coverPath, (_) => _refreshDirty()),
      ever(isFavorite, (_) => _refreshDirty()),
    ]);
  }

  /// Kaydedilmemiş değişiklik var mı? Açılış görüntüsüyle karşılaştırır.
  void _refreshDirty() {
    isDirty.value = _computeDirty();
  }

  bool _computeDirty() {
    for (final entry in _initialTexts.entries) {
      if (entry.key.text != entry.value) return true;
    }
    return status.value != _initialStatus ||
        startedAt.value != _initialStartedAt ||
        finishedAt.value != _initialFinishedAt ||
        targetFinishDate.value != _initialTargetDate ||
        coverUrl.value != _initialCoverUrl ||
        coverPath.value != _initialCoverPath ||
        isFavorite.value != _initialFavorite;
  }

  /// Geri/çıkış isteğinde kaydedilmemiş değişiklik varsa kullanıcıya
  /// sorulur: "Çıkmak istediğinden emin misin?" Onaylarsa sayfa açılır,
  /// yazdıkları kaybolur; vazgeçerse form yerinde kalır.
  Future<void> confirmDiscardChanges() async {
    final leave = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Çıkmak istediğinden emin misin?'),
        content: const Text(
          'Yazdığın bilgiler kaydedilmedi.\n\n'
          'Çıkarsan bu bilgiler kaybolur; vazgeçersen formda kalırsın.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('discard-stay'),
            onPressed: () => AppNav.pop<bool>(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            key: const ValueKey('discard-leave'),
            onPressed: () => AppNav.pop<bool>(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (leave != true) return;
    _closeForm();
  }

  /// Formu KAPATIR. PopScope canPop'ı [isDirty]'e bağlıdır; programatik
  /// pop'un rotadan engellenmemesi için önce kirli bayrağı temizlenir,
  /// sonra BİR kare beklenip pop edilir (rebuild bu karede tamamlanır).
  /// Kaydet akışı da aynı yolu kullanır: kayıttan sonra form kapanmalı,
  /// ama kirli formda PopScope pop'u yutar ve diyalog açardı.
  void _closeForm() {
    isDirty.value = false;
    SchedulerBinding.instance.addPostFrameCallback((_) => AppNav.pop());
  }

  /// Formdaki "Favori" anahtarı; kayıtta [BookModel.isFavorite]'a yazılır.
  void setFavorite(bool value) => isFavorite.value = value;

  // ---------- Kapak fotoğrafı ----------

  /// Kamerayla kitabın fotoğrafını çeker ve kalıcı kopyayı forma ekler.
  Future<void> takePhoto() => _attachPhoto(_photoPicker.takePhoto);

  /// Galeriden kitap fotoğrafı seçer ve kalıcı kopyayı forma ekler.
  Future<void> pickFromGallery() => _attachPhoto(_photoPicker.pickFromGallery);

  Future<void> _attachPhoto(Future<String?> Function() source) async {
    if (isPhotoBusy.value) return;
    isPhotoBusy.value = true;
    try {
      final tempPath = await source();
      if (tempPath == null) return; // Kullanıcı vazgeçti.
      final saved = await _photoStore.saveFromTemp(tempPath);
      final previous = coverPath.value;
      coverPath.value = saved;
      // Aynı oturumda önceki seçimin dosyası artık referanssız; hemen
      // temizle. Formun açılışındaki orijinal fotoğrafa ise ancak kaydetme
      // BAŞARILI olduktan sonra dokunulur: kullanıcı vazgeçerse eski
      // fotoğraf kayıtta yerinde kalır.
      if (previous != null && previous != _originalCoverPath) {
        unawaited(_photoStore.delete(previous));
      }
    } catch (_) {
      _toast(
        'Fotoğraf eklenemedi',
        'Kamera ya da galeri şu an kullanılamıyor.',
      );
    } finally {
      isPhotoBusy.value = false;
    }
  }

  /// Formdan fotoğrafı kaldırır; diskteki dosya kaydetme onayından sonra
  /// silinir (bkz. [save]).
  void removePhoto() => coverPath.value = null;

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
        _toast(
          'Bulunamadı',
          "Open Library'de kayıt yok. Bilgileri elle girebilirsin.",
        );
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
    } on NetworkException catch (error) {
      _toast('Bağlantı sorunu', error.message);
    } finally {
      isFetching.value = false;
    }
  }

  Future<void> scanIsbn() async {
    // GetX rotaları GetPageRoute<dynamic> olarak kurulur. Burada
    // Get.toNamed<String> kullanırsak Flutter Navigator rotayı
    // Route<String?>'e cast etmeye çalışır ve runtime'da
    // "GetPageRoute<dynamic> is not a subtype of Route<String?>"
    // hatası fırlatır. Bu yüzden generic vermiyoruz; sonucu tipte
    // savunmacı şekilde ele alıyoruz.
    final result = await Get.toNamed(Routes.scanner);
    final code = result is String ? result.trim() : null;
    if (code == null || code.isEmpty) return;

    // Aynı ISBN başka bir kitapta kullanılıyorsa üzerine yazmak yerine uyar.
    if (_library.hasIsbnConflict(code, exceptId: _id)) {
      _toast(
        'ISBN zaten kitaplıkta',
        'Bu barkod farklı bir kitaba kayıtlı; alan değiştirilmedi.',
      );
      return;
    }

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
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          target.value?.isAfter(now.add(const Duration(days: 1))) ?? false
              ? now
              : (target.value ?? now),
      firstDate: DateTime(1990),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) target.value = picked;
  }

  /// Bitirme hedefi: gelecekte bir tarih seçilir; geçmiş tarih seçilemez
  /// (hedefin anlamı bu). Temizleme [clearTargetDate] ile yapılır.
  Future<void> pickTargetDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          targetFinishDate.value ?? today.add(const Duration(days: 30)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 10)),
      helpText: 'Bitirme hedefi seç',
    );
    if (picked != null) targetFinishDate.value = picked;
  }

  /// Bitirme hedefini kaldırır.
  void clearTargetDate() => targetFinishDate.value = null;

  // ---------- Kaydet ----------

  Future<void> save() async {
    // Çift tıklama / double-submit koruması.
    if (isSaving.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    final pages = int.tryParse(pagesCtrl.text.trim()) ?? 0;
    var current = int.tryParse(currentPageCtrl.text.trim()) ?? 0;
    final s = status.value;
    if (s == ReadingStatus.notStarted) current = 0;
    if (s == ReadingStatus.finished && pages > 0) current = pages;

    final isbn = _nullIfEmpty(isbnCtrl.text);
    if (isbn != null && _library.hasIsbnConflict(isbn, exceptId: _id)) {
      // Aynı ISBN başka bir kitapta: yanlışlıkla çift kayıt yerine bilinçli
      // kopya olarak kaydetmeyi onaylat. Kopyaların okuma durumları bağımsızdır.
      final saveAsCopy = await _confirmSaveAsCopy();
      if (!saveAsCopy) return;
    }

    final book = BookModel(
      id: _id,
      title: titleCtrl.text.trim(),
      authors: authorsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      isbn: isbn,
      coverUrl: coverUrl.value,
      coverPath: coverPath.value,
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
      isFavorite: isFavorite.value,
      targetFinishDate: targetFinishDate.value,
      addedAt: _addedAt,
    );

    isSaving.value = true;
    try {
      final ok = await _library.saveBook(book);
      if (!ok) return; // Hata mesajı LibraryController tarafından gösterildi.
      // Kayıt başarılı: eski fotoğraf artık hiçbir kayıtta kullanılmıyorsa
      // diskten silinir. Kullanıcı fotoğrafı değiştirdi/kaldırdıysa eski
      // dosya sahipsiz kalmıştır.
      final oldPath = _originalCoverPath;
      if (oldPath != null && oldPath != book.coverPath) {
        unawaited(_photoStore.delete(oldPath));
      }
      // AppNav.pop: snackbar açıkken Get.back() pop yapmadan döndüğü için
      // (GetX 4.x snackbar uyumluluk davranışı) navigator doğrudan pop'lanır.
      // PopScope ile uyumlu kapatma: kirli formda da güvenli (bkz.
      // [_closeForm]).
      _closeForm();
      Get.snackbar('Kaydedildi', book.title,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSaving.value = false;
    }
  }

  // ---------- Yardımcılar ----------

  /// Aynı ISBN kayıtlıyken kaydet tuşuna basıldıysa: "farklı kopya olarak
  /// kaydet" onayı. `true` → kayda devam; `false` → vazgeç.
  Future<bool> _confirmSaveAsCopy() async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Bu ISBN kitaplıkta'),
        content: const Text(
          'Aynı ISBN\'e sahip başka bir kitap var. Bu kitabı aynı kitabın '
          'farklı bir kopyası olarak kaydetmek istiyor musun?\n\n'
          'Kopyalar birbirinden bağımsızdır: her birinin okuma durumu, '
          'sayfası ve günlüğü ayrı tutulur.',
        ),
        actions: [
          TextButton(
            onPressed: () => AppNav.pop<bool>(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => AppNav.pop<bool>(true),
            child: const Text('Kopya olarak kaydet'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

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
    for (var i = 0; i < _textControllers.length; i++) {
      _textControllers[i].removeListener(_textListeners[i]);
    }
    for (final worker in _workers) {
      worker.dispose();
    }
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

  /// ISBN alanının doğrulaması: boş geçilebilir; doluysa kontrol hanesi
  /// geçerli olmalı. Barkodla okunan ISBN'ler (EAN-13) zaten geçerlidir.
  String? validateIsbn(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    if (IsbnValidator.isValid(IsbnValidator.clean(v))) return null;
    return 'Bu geçerli bir ISBN gibi görünmüyor. Hatalıysa alanı temizle.';
  }
}

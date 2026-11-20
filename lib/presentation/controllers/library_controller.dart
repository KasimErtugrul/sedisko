import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';
import '../../data/models/reading_log_entry.dart';
import '../../data/services/cover_photo_store.dart';
import '../../domain/repositories/book_repository.dart';
import '../../domain/services/book_sort.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../utils/app_navigation.dart';

class LibraryController extends GetxController {
  /// [onNotify] test edilebilirlik için verilir; verilmezse GetX snackbar
  /// gösterilir. [coverStore] verilirse kitap silindiğinde fotoğraf
  /// dosyası da diskten temizlenir. [deleteUndoWindow] "Geri Al" şansının
  /// süresidir (test edilebilirlik için verilir); verilmezse snackbar'ın
  /// altı saniyesine bir saniye pay bırakılır.
  LibraryController(
    this._repository, {
    void Function(String title, String message)? onNotify,
    CoverPhotoStore? coverStore,
    Duration deleteUndoWindow = const Duration(seconds: 7),
  })  : _notify = onNotify ?? _defaultNotify,
        _coverStore = coverStore,
        _deleteUndoWindow = deleteUndoWindow;

  final BookRepository _repository;
  final CoverPhotoStore? _coverStore;
  final Duration _deleteUndoWindow;

  /// Keşke 31 (1.23.0): "Bir gün yanlışlıkla basarsam kitabım gidiyor" —
  /// silinen kitap "Geri Al" süresi boyunca bellekte tutulur; fotoğraf
  /// dosyası da o süre bitmeden silinmez. Süre dolunca
  /// [discardLastDeleted] gerçek silme sonunu tamamlar.
  BookModel? _lastDeleted;
  Timer? _undoTimer;

  final void Function(String title, String message) _notify;

  final books = <BookModel>[].obs;
  final isLoading = false.obs;
  final isLookingUp = false.obs;
  final query = ''.obs;

  /// Ana sayfadaki arama alanının denetleyicisi (temizle butonu için).
  final searchCtrl = TextEditingController();

  final statusFilter = Rxn<ReadingStatus>();

  /// Yazar filtresi anahtarı (TextNormalizer.searchKey ile üretilir).
  /// Yalnız raf sayfası bağlamında anlamlıdır; sayfa kapanınca sıfırlanır.
  final authorFilter = Rxn<String>();

  /// Aktif sıralama alanı ve yönü. Varsayılan: kitap adı artan.
  /// `books` listesinin kendi raf/ada düzeni (ana sayfa bölümleri ve
  /// raf kartlarının beklediği) korunur; sıralama [filteredBooks] ve
  /// [sortedAll] çıktısına uygulanır.
  final sortField = BookSortField.title.obs;
  final sortAscending = true.obs;

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
    // Denetleyici kapanırken bekleyen "Geri Al" varsa gerçek silme sonunu
    // (fotoğraf temizliği) tamamla; yoksa dosya sahipsiz kalır.
    discardLastDeleted();
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

  /// Sıralamayı ayarlar.
  ///
  /// [ascending] verilmezse: aynı alan yeniden seçiliyken yön çevrilir
  /// (artan ↔ azalan); yeni alanda varsayılan artan kalır.
  void setSort(BookSortField field, {bool? ascending}) {
    if (ascending == null && field == sortField.value) {
      sortAscending.value = !sortAscending.value;
      return;
    }
    sortField.value = field;
    sortAscending.value = ascending ?? true;
  }

  /// Sıralama varsayılanından (kitap adı artan) farklıysa true; AppBar
  /// rozetinde kullanılır.
  bool get hasCustomSort =>
      sortField.value != BookSortField.title || !sortAscending.value;

  // ---------- Sorgular ----------

  /// Türkçe İ/ı eşleşmesini koruyan arama: kitap adı, yazar, raf ve ISBN.
  ///
  /// [shelf] verilirse yalnız o raftaki kitaplar döner ('Rafsız' anahtarı
  /// rafsız kitapları seçer); verilmezse tüm kitaplık taranır. Arama sonuçları
  /// (rafsız tüm kitaplık) ve raf sayfası (tek raf) bu tek metodu paylaşır.
  List<BookModel> filteredBooks({String? shelf}) {
    final q = TextNormalizer.searchKey(query.value.trim());
    final status = statusFilter.value;
    final authorKey = authorFilter.value;
    final result = books.where((b) {
      if (shelf != null) {
        final bookShelf = b.shelf.trim();
        final matches =
            shelf == 'Rafsız' ? bookShelf.isEmpty : bookShelf == shelf;
        if (!matches) return false;
      }
      if (status != null && b.status != status) return false;
      if (authorKey != null && !_hasAuthor(b, authorKey)) return false;
      if (q.isEmpty) return true;
      return TextNormalizer.searchKey(b.title).contains(q) ||
          TextNormalizer.searchKey(b.authorsText).contains(q) ||
          TextNormalizer.searchKey(b.shelf).contains(q) ||
          TextNormalizer.searchKey(b.isbn ?? '').contains(q);
    }).toList();

    // Raf/arama/durum filtresinden sonra aktif sıralama uygulanır:
    // raf sayfası, arama sonuçları ve yazar görünümü tek merkezde
    // sıralanır (BookSorter eksik değerleri her yönde sona atar).
    BookSorter.sort(result, sortField.value, sortAscending.value);
    return result;
  }

  /// Kitaplığın tamamı, aktif sıralamayla. Arama/durum filtreleri
  /// uygulanmaz; daima tam listeyi verir (testler ve genel sorgular için).
  List<BookModel> get sortedAll {
    final list = books.toList();
    BookSorter.sort(list, sortField.value, sortAscending.value);
    return list;
  }

  /// Kitaplıktaki yazarlar; büyük harf/aksan farkları tek isimde
  /// birleştirilir ("orhan pamuk" ile "Orhan Pamuk" aynı grup olur).
  /// Görünen ad ilk görülen yazım; sıralama Türkçe alfabeye göredir.
  List<String> get authors {
    final displayByKey = <String, String>{};
    for (final b in books) {
      for (final raw in b.authors) {
        final author = raw.trim();
        if (author.isEmpty) continue;
        displayByKey.putIfAbsent(
          TextNormalizer.searchKey(author),
          () => author,
        );
      }
    }
    return displayByKey.values.toList()..sort(TextNormalizer.compareTr);
  }

  /// [authorKey] için görünen yazar adı; kitaplıkta yoksa `null`.
  String? authorDisplayName(String authorKey) {
    for (final b in books) {
      for (final raw in b.authors) {
        final author = raw.trim();
        if (author.isNotEmpty &&
            TextNormalizer.searchKey(author) == authorKey) {
          return author;
        }
      }
    }
    return null;
  }

  /// [authorKey] grubundaki kitap sayısı (yazarlar sekmesi kartı).
  int authorBookCount(String authorKey) =>
      books.where((b) => _hasAuthor(b, authorKey)).length;

  /// [authorKey] grubunun kitaplıkta geçen farklı yazımları (ilk görülme
  /// sırasıyla).
  ///
  /// Open Library verisi Türkçe karakterleri sadeleştirebilir: aynı yazar
  /// "Kasım" ve "Kasim" yazımlarıyla iki kitapta bulunabilir. İki yazım da
  /// aynı arama anahtarına katlandığı için listede tek kart görünür; bu
  /// metot kartın arkasındaki yazım çeşitliliğini görünür kılar ve
  /// birleştirme ([renameAuthor]) kararında kullanıcıya gösterilir.
  List<String> authorSpellings(String authorKey) {
    final seen = <String>[];
    for (final b in books) {
      for (final raw in b.authors) {
        final author = raw.trim();
        if (author.isEmpty) continue;
        if (TextNormalizer.searchKey(author) == authorKey &&
            !seen.contains(author)) {
          seen.add(author);
        }
      }
    }
    return seen;
  }

  /// [authorKey] grubundaki TÜM kitapların yazar bilgisini [newName]'e
  /// çevirir; güncellenen kitap sayısını döner.
  ///
  /// - Birleştirme: yazarın tüm yazımları tek isimde toplanır ("Kasim"
  ///   yazan kitapların hepsi "Kasım" olur). Listede zaten tek kart
  ///   görünüyordu; bu işlem veriyi de tek yazıma sabitler.
  /// - Aynı kitabın yazar listesinde birden fazla varyant varsa tek isimde
  ///   birleştirilir; DİĞER yazarlar ve sıraları korunur.
  /// - Hedef ad, kitaplıkta başka bir yazar grubuysa doğal birleşme olur:
  ///   kitaplar o grubun kitaplarına eklenir.
  /// - Okuma günlüğü ve diğer alanlar değişmez (deriveLog: false).
  /// - Depo hatasında kalan kitaplar dokunulmaz (kısmi güncelleme mümkün);
  ///   hata mesajı saveBook içinde gösterilir.
  Future<int> renameAuthor(String authorKey, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return 0;

    var changed = 0;
    for (final book in List<BookModel>.of(books)) {
      if (!_hasAuthor(book, authorKey)) continue;

      final replaced = <String>[];
      var touched = false;
      for (final raw in book.authors) {
        final author = raw.trim();
        if (author.isEmpty) continue;
        if (TextNormalizer.searchKey(author) == authorKey) {
          touched = true;
          if (!replaced.contains(name)) replaced.add(name);
        } else if (!replaced.contains(author)) {
          replaced.add(author);
        }
      }
      if (!touched) continue;

      final ok = await saveBook(
        book.copyWith(authors: replaced),
        deriveLog: false,
      );
      if (!ok) break;
      changed++;
    }
    return changed;
  }

  /// Kitabın yazarları arasında [authorKey] ile eşleşen var mı?
  bool _hasAuthor(BookModel book, String authorKey) => book.authors
      .any((a) => TextNormalizer.searchKey(a.trim()) == authorKey);

  /// [book] ile aynı ISBN'e sahip diğer kopyalar (kendisi hariç).
  ///
  /// Kopyalar bilinçli çoklu kayıtlardır: her birinin okuma durumu, sayfası
  /// ve günlüğü birbirinden bağımsızdır. ISBN'i olmayan kitapların kopya
  /// eşleşmesi yapılmaz (başlıklar yanıltıcı olur).
  List<BookModel> copiesOf(BookModel book) {
    final clean = _cleanIsbn(book.isbn ?? '');
    if (clean.isEmpty) return const <BookModel>[];
    return books
        .where((b) => b.id != book.id && _cleanIsbn(b.isbn ?? '') == clean)
        .toList();
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

  /// Raf kartları için anahtarlar: dolu raflar (Türkçe sıralı) ve
  /// rafsız kitap varsa sonda 'Rafsız'.
  List<String> get shelfKeys {
    final keys = [...shelves];
    if (books.any((b) => b.shelf.trim().isEmpty)) keys.add('Rafsız');
    return keys;
  }

  /// [shelfKey] rafındaki kitap sayısı ('Rafsız' anahtarı dahil).
  int shelfCount(String shelfKey) {
    if (shelfKey == 'Rafsız') {
      return books.where((b) => b.shelf.trim().isEmpty).length;
    }
    return books.where((b) => b.shelf.trim() == shelfKey).length;
  }

  // ---------- Ana sayfa bölümleri ----------

  /// Favori işaretli kitaplar (ana sayfa "Favoriler" şeridi).
  List<BookModel> get favoriteBooks =>
      books.where((b) => b.isFavorite).toList();

  /// Notu olan kitaplar (ana sayfa "Not aldıkların" şeridi).
  List<BookModel> get notedBooks =>
      books.where((b) => (b.notes ?? '').trim().isNotEmpty).toList();

  /// Bitirme hedefi koymuş, henüz bitmemiş kitaplar (ana sayfa "Bitirme
  /// hedefleri" şeridi). En yakın hedef önce; tarihi geçenler en başta
  /// (gecikme en acil) görünür. Aynı tarihliler kitap adına göre
  /// sıralanır: liste her kurulumda aynı sırayla gelir.
  List<BookModel> get goalBooks {
    final list = books
        .where((b) =>
            b.targetFinishDate != null && b.status != ReadingStatus.finished)
        .toList();
    list.sort((a, b) {
      final byDate = a.targetFinishDate!.compareTo(b.targetFinishDate!);
      if (byDate != 0) return byDate;
      return TextNormalizer.compareTr(a.title, b.title);
    });
    return list;
  }

  /// Sayfa sayısı bilinen en kalın kitaplar (ana sayfa "En çok sayfalı
  /// kitaplar" şeridi). Azalan sayfa sayısı; eşitlikte kitap adı, o da
  /// eşitse id (kararlı sıra). En fazla 10 kitap döner.
  List<BookModel> get longestBooks {
    final list = books.where((b) => b.pageCount > 0).toList();
    list.sort((a, b) {
      final byPages = b.pageCount.compareTo(a.pageCount);
      if (byPages != 0) return byPages;
      final byTitle = TextNormalizer.compareTr(a.title, b.title);
      if (byTitle != 0) return byTitle;
      return a.id.compareTo(b.id);
    });
    return list.take(10).toList();
  }

  /// [shelfKey] rafındaki okumada olan kitap sayısı ('Rafsız' dahil).
  /// Raf kartlarının zengin özetinde kullanılır.
  int shelfReadingCount(String shelfKey) => _shelfStatusCount(
        shelfKey,
        (b) => b.status == ReadingStatus.reading,
      );

  /// [shelfKey] rafındaki bitmiş kitap sayısı ('Rafsız' dahil).
  int shelfFinishedCount(String shelfKey) => _shelfStatusCount(
        shelfKey,
        (b) => b.status == ReadingStatus.finished,
      );

  int _shelfStatusCount(String shelfKey, bool Function(BookModel) test) {
    if (shelfKey == 'Rafsız') {
      return books
          .where((b) => b.shelf.trim().isEmpty && test(b))
          .length;
    }
    return books.where((b) => b.shelf.trim() == shelfKey && test(b)).length;
  }

  /// Okumada olan kitaplar (ana sayfa "Devam eden kitaplar" şeridi).
  List<BookModel> get readingBooks =>
      books.where((b) => b.status == ReadingStatus.reading).toList();

  int get readingCount => readingBooks.length;

  int get finishedCount =>
      books.where((b) => b.status == ReadingStatus.finished).length;

  /// Favori işaretini tersine çevirir; okuma durumu/günlük dokunulmaz.
  Future<void> toggleFavorite(BookModel book) =>
      saveBook(book.copyWith(isFavorite: !book.isFavorite), deriveLog: false);

  // ---------- Raf taşıma ----------

  /// Kitabı başka bir rafa taşır; okuma durumu, sayfa ve günlük değişmez.
  /// [shelf] boş verilirse kitap rafsız olur. Aynı rafa taşımak no-op'tur.
  Future<bool> moveToShelf(BookModel book, String shelf) {
    final target = shelf.trim();
    if (target == book.shelf.trim()) return Future<bool>.value(true);
    return saveBook(book.copyWith(shelf: target), deriveLog: false);
  }

  /// [targets] listesini tek rafa toplar; kaç kitabın taşındığını döner.
  /// Zaten hedef rafta olanlar atlanır. Depo hatasında kalan kitaplar
  /// taşınmaz (kısmi taşınma mümkündür).
  Future<int> moveManyToShelf(List<BookModel> targets, String shelf) async {
    final target = shelf.trim();
    var moved = 0;
    for (final book in targets) {
      if (book.shelf.trim() == target) continue;
      final ok = await saveBook(book.copyWith(shelf: target), deriveLog: false);
      if (!ok) break;
      moved++;
    }
    return moved;
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
  ///
  /// [deriveLog] `false` verilirse günlük hiç hesaplanmaz ve kitabın
  /// mevcut günlüğü aynen korunur (raf taşıma, favori çevrimi gibi okuma
  /// durumuyla ilgisi olmayan yazmalarda istenmeyen kayıt oluşmasını önler).
  Future<bool> saveBook(BookModel book, {bool deriveLog = true}) async {
    final merged = deriveLog
        ? book.copyWith(
            readingLog: _mergedReadingLog(byId(book.id), book),
          )
        : book;
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

  /// Kitabı siler. [allowUndo] `true` verilirse (kitap detay sayfasındaki
  /// silme akışı) kitap "Geri Al" süresi boyunca bellekte tutulur ve
  /// [restoreLastDeleted] ile silinmeden önceki haliyle geri konabilir;
  /// fotoğraf dosyası o süre bitmeden silinmez. Süre dolunca
  /// [discardLastDeleted] temizliği yapar. `false` (eski davranış) ya da
  /// kitaplıkta kayıt yokken fotoğraf hemen temizlenir.
  ///
  /// Veri anahtarları değişmez: geri alma, kitabı AYNI kimlikle depoya
  /// yeniden yazar ([saveBook] — günlük aynen korunur, deriveLog kapalı).
  Future<bool> deleteBook(String id, {bool allowUndo = false}) async {
    final book = byId(id);
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
    if (allowUndo && book != null) {
      _lastDeleted = book;
      _undoTimer?.cancel();
      _undoTimer = Timer(_deleteUndoWindow, discardLastDeleted);
      return true;
    }
    // Fotoğraf dosyası artık hiçbir kayıtta kullanılmıyor; diskten de
    // temizlenir. Depo içindeki silme kendi hatalarını yutar: temizlik
    // sorunu silme işleminin sonucunu etkilemez.
    await _coverStore?.delete(book?.coverPath);
    return true;
  }

  /// "Geri Al" süresi doldu ya da denetleyici kapanıyor: silinen kitap
  /// unutulur ve fotoğraf dosyası diskten temizlenir (silmenin gerçek
  /// sonu). Bu çağrıdan sonra [restoreLastDeleted] artık geri koyamaz.
  void discardLastDeleted() {
    _undoTimer?.cancel();
    _undoTimer = null;
    final path = _lastDeleted?.coverPath;
    _lastDeleted = null;
    if (path != null) _coverStore?.delete(path);
  }

  /// Silinen son kitabı silinmeden önceki haliyle geri koyar: aynı
  /// kimlik, raf, okuma durumu, sayfa ve günlük. Depoya aynı kimlikle
  /// yazılır; geri koyulacak kayıt yoksa ya da "Geri Al" süresi dolduysa
  /// `false` döner.
  Future<bool> restoreLastDeleted() async {
    final book = _lastDeleted;
    if (book == null) return false;
    _undoTimer?.cancel();
    _undoTimer = null;
    _lastDeleted = null;
    return saveBook(book, deriveLog: false);
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
      final action = await _duplicateIsbnDialog(existing);
      switch (action) {
        case _DuplicateIsbnAction.view:
          Get.toNamed(Routes.detail, arguments: existing.id);
          return;
        case _DuplicateIsbnAction.cancel:
          return;
        case _DuplicateIsbnAction.addCopy:
          break; // Aynı kitabın yeni bir kopyası olarak akışa devam.
      }
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

  /// Aynı ISBN tekrar tarandığında kullanıcıya seçenek sunar: mevcut kitabı
  /// gör ya da aynı kitabın yeni bir kopyasını ekle (ör. okunacak + rafa
  /// konulacak ikinci nüsha). Kopyaların okuma durumları bağımsızdır.
  Future<_DuplicateIsbnAction> _duplicateIsbnDialog(BookModel existing) async {
    final result = await Get.dialog<_DuplicateIsbnAction>(
      AlertDialog(
        title: const Text('Bu ISBN kitaplıkta'),
        content: Text(
          '"${existing.title}" bu ISBN ile kayıtlı.\n\n'
          'Ne yapmak istersin?',
        ),
        actions: [
          TextButton(
            onPressed: () => AppNav.pop<_DuplicateIsbnAction>(
              _DuplicateIsbnAction.cancel,
            ),
            child: const Text('Vazgeç'),
          ),
          OutlinedButton(
            onPressed: () => AppNav.pop<_DuplicateIsbnAction>(
              _DuplicateIsbnAction.view,
            ),
            child: const Text('Kitabı gör'),
          ),
          FilledButton(
            onPressed: () => AppNav.pop<_DuplicateIsbnAction>(
              _DuplicateIsbnAction.addCopy,
            ),
            child: const Text('Yeni kopya ekle'),
          ),
        ],
      ),
    );
    return result ?? _DuplicateIsbnAction.cancel;
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

/// Aynı ISBN tekrar eklendiğinde diyaloğun sonucu.
enum _DuplicateIsbnAction { cancel, view, addCopy }

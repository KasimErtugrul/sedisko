import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/text_normalizer.dart';
import '../datasources/book_local_datasource.dart';
import '../datasources/shelf_local_datasource.dart';
import '../models/backup_model.dart';
import '../models/book_model.dart';
import '../models/shelf_model.dart';

/// İçe aktarma kipi.
enum BackupImportMode {
  /// Mevcut veri korunur; yedekteki yeni kitap/raflar eklenir, aynı
  /// kitaplar atlanır. İki kişinin kitaplığını birleştirmek için.
  merge,

  /// Mevcut kitap ve raf tanımları SİLİNİR; yedekten geri yüklenir.
  /// "Eşimin kitaplığını aynen bende de istiyorum" senaryosu için.
  replace,
}

/// İçe aktarmanın sonucu; başarı ekranındaki özet mesajı da burada üretilir.
class BackupImportSummary extends Equatable {
  const BackupImportSummary({
    required this.mode,
    required this.booksImported,
    required this.booksSkipped,
    required this.shelvesImported,
    required this.shelvesKept,
    required this.planCleared,
  });

  final BackupImportMode mode;

  /// Cihaza yazılan (yeni) kitap sayısı.
  final int booksImported;

  /// Birleştirmede zaten var olduğu için atlanan kitap sayısı.
  final int booksSkipped;

  /// Cihaza yazılan (yeni) raf sayısı.
  final int shelvesImported;

  /// Birleştirmede adı mevcut raf-la eşleşen, aynen kullanılan raf sayısı.
  final int shelvesKept;

  /// "Üzerine yaz"da eski taşıma planı sıfırlandı mı?
  final bool planCleared;

  @override
  List<Object?> get props =>
      [mode, booksImported, booksSkipped, shelvesImported, shelvesKept, planCleared];
}

/// Kitaplık yedeğini üreten ve geri yükleyen servis.
///
/// Yedek dosyası iki cihaz arasında TAŞINABİLİR olduğu için buradaki
/// mantık tamamen deterministtir: aynı veri + aynı mevcut durum her zaman
/// aynı sonucu üretir (rastgelelik yalnızca kimlik çakışması çözümünde,
/// yeni kimlik üretirken devreye girer).
class BackupService {
  BackupService({
    required BookLocalDataSource bookStore,
    required ShelfLocalDataSource shelfStore,
  })  : _bookStore = bookStore,
        _shelfStore = shelfStore;

  final BookLocalDataSource _bookStore;
  final ShelfLocalDataSource _shelfStore;

  /// Mevcut veritabanından paylaşılacak zarfı toplar.
  BackupEnvelope buildEnvelope() {
    return BackupEnvelope(
      exportedAt: DateTime.now(),
      appVersion: AppInfo.version,
      books: _bookStore.getBooks(),
      shelves: _shelfStore.getShelves(),
    );
  }

  /// Doğrulanmış zarfı cihaza uygular.
  ///
  /// Zarf [BackupEnvelope.parse] ile doğrulanmış olmalıdır; "üzerine yaz"
  /// mevcut veriyi sildiği için buraya hatalı zarf gelmesi durumunda
  /// hiçbir depoya dokunulmaz.
  Future<BackupImportSummary> applyImport(
    BackupEnvelope envelope,
    BackupImportMode mode,
  ) {
    if (mode == BackupImportMode.replace) {
      return _applyReplace(envelope);
    }
    return _applyMerge(envelope);
  }

  // ---------- Üzerine yaz ----------

  Future<BackupImportSummary> _applyReplace(BackupEnvelope envelope) async {
    // Sıra bilinçlidir: önce raflar, sonra kitaplar. Ara bir hatada
    // kitapların raf alanı raf tanımlarından bağımsız yaşadığı için
    // tutarsızlık yalnızca geçicidir; iki yazma da atomik anahtar yazımıdır.
    await _shelfStore.saveShelves(envelope.shelves);
    await _bookStore.replaceAll(envelope.books);
    // Eski plan, artık var olmayan raf/kitap kimliklerine işaret eder;
    // temizlenir (yeniden düzenleme istenirse yeniden planlanır).
    await _shelfStore.savePlan(null);

    return BackupImportSummary(
      mode: BackupImportMode.replace,
      booksImported: envelope.books.length,
      booksSkipped: 0,
      shelvesImported: envelope.shelves.length,
      shelvesKept: 0,
      planCleared: true,
    );
  }

  // ---------- Birleştir ----------

  Future<BackupImportSummary> _applyMerge(BackupEnvelope envelope) async {
    final existingShelves = _shelfStore.getShelves();
    final existingBooks = _bookStore.getBooks();

    // 1) Raflar: ad eşleşmesi (Türkçe katlamayla) varsa mevcut raf aynen
    //    kullanılır; yoksa yedekteki raf eklenir. Kimlik çakışması varsa
    //    yeni kimlik üretilir — kitaplar rafu ADLA takip ettiği için
    //    kimlik yalnızca raf tanımının kendisini ilgilendirir.
    final shelves = List<ShelfModel>.of(existingShelves);
    // MEVCUT raflar baştan haritaya eklenir: kitabın raf alanı, zarfta o
    // raf olmasa bile eşleşen mevcut rafın kanonik adına çekilmelidir.
    final canonicalNameByFold = <String, String>{
      for (final shelf in existingShelves)
        TextNormalizer.searchKey(shelf.name): shelf.name,
    };
    final usedShelfIds = <String>{
      for (final shelf in existingShelves) shelf.id,
    };
    var shelvesImported = 0;
    var shelvesKept = 0;

    for (final incoming in envelope.shelves) {
      final fold = TextNormalizer.searchKey(incoming.name);
      final canonical = canonicalNameByFold[fold];
      if (canonical != null) {
        // Kanonik ad aynıdır (mevcut raf korunur); haritayı güncelle.
        canonicalNameByFold[fold] = canonical;
        shelvesKept++;
        continue;
      }
      final id = _uniqueId(incoming.id, usedShelfIds);
      final mergedShelf = ShelfModel(
        id: id,
        name: incoming.name,
        capacity: incoming.capacity,
        location: incoming.location,
        order: incoming.order,
      );
      shelves.add(mergedShelf);
      usedShelfIds.add(id);
      canonicalNameByFold[fold] = mergedShelf.name;
      shelvesImported++;
    }

    // 2) Kitaplar: ISBN ya da (başlık+yazar) çifti eşleşirse atlanır;
    //    değilse eklenir. Kimlik çakışmasında yeni kimlik üretilir.
    final isbnKeys = <String>{};
    final titleAuthorKeys = <String>{};
    final usedBookIds = <String>{};
    for (final book in existingBooks) {
      final isbnKey = _isbnKey(book);
      if (isbnKey != null) isbnKeys.add(isbnKey);
      final ta = _titleAuthorKey(book);
      if (ta != null) titleAuthorKeys.add(ta);
      usedBookIds.add(book.id);
    }

    final addedBooks = <BookModel>[];
    var booksSkipped = 0;
    for (final incoming in envelope.books) {
      final isbnKey = _isbnKey(incoming);
      // ISBN'siz kitaplar boş anahtarla eşleşemez: yoksa ISBN'siz BÜTÜN
      // gelen kitaplar, ISBN'siz tüm mevcut kitaplarla "aynı" sanılırdı.
      if (isbnKey != null && isbnKeys.contains(isbnKey)) {
        booksSkipped++;
        continue;
      }
      final ta = _titleAuthorKey(incoming);
      if (ta != null && titleAuthorKeys.contains(ta)) {
        booksSkipped++;
        continue;
      }

      var book = incoming;
      if (usedBookIds.contains(book.id)) {
        book = _withNewId(book, usedBookIds);
      }
      // Kitabın raf alanı, eşleşen mevcut rafın KANONİK adına çekilir
      // ('roman' → 'Roman'); aksi halde aynı fiziksel raf iki farklı adla
      // görünürdü.
      if (book.shelf.isNotEmpty) {
        final canonical =
            canonicalNameByFold[TextNormalizer.searchKey(book.shelf)];
        if (canonical != null && canonical != book.shelf) {
          book = book.copyWith(shelf: canonical);
        }
      }

      usedBookIds.add(book.id);
      if (isbnKey != null) isbnKeys.add(isbnKey);
      if (ta != null) titleAuthorKeys.add(ta);
      addedBooks.add(book);
    }

    if (shelvesImported > 0) {
      await _shelfStore.saveShelves(shelves);
    }
    if (addedBooks.isNotEmpty) {
      await _bookStore.addMany(addedBooks);
    }
    // Birleştirme mevcut rafları koruduğu için sürüyor olan plan geçerli
    // kalır; yalnız plana yeni eklenen kitaplar yansımazsa kullanıcı
    // "Yeniden planla" ile güncelleyebilir.

    return BackupImportSummary(
      mode: BackupImportMode.merge,
      booksImported: addedBooks.length,
      booksSkipped: booksSkipped,
      shelvesImported: shelvesImported,
      shelvesKept: shelvesKept,
      planCleared: false,
    );
  }

  /// Kimlik çakışmasını çözerek benzersiz kimlik döner.
  String _uniqueId(String candidate, Set<String> used) {
    if (!used.contains(candidate)) return candidate;
    return BookModel.newId();
  }

  BookModel _withNewId(BookModel book, Set<String> used) {
    while (true) {
      final id = BookModel.newId();
      if (!used.contains(id)) {
        return BookModel(
          id: id,
          title: book.title,
          authors: book.authors,
          isbn: book.isbn,
          coverUrl: book.coverUrl,
          coverPath: book.coverPath,
          publisher: book.publisher,
          publishDate: book.publishDate,
          pageCount: book.pageCount,
          shelf: book.shelf,
          status: book.status,
          currentPage: book.currentPage,
          startedAt: book.startedAt,
          finishedAt: book.finishedAt,
          notes: book.notes,
          isManual: book.isManual,
          isFavorite: book.isFavorite,
          readingLog: book.readingLog,
          targetFinishDate: book.targetFinishDate,
          addedAt: book.addedAt,
        );
      }
    }
  }

  String? _isbnKey(BookModel book) {
    final isbn = (book.isbn ?? '').trim().toLowerCase();
    return isbn.isEmpty ? null : isbn;
  }

  /// Başlık+yazar anahtarı: Türkçe katlamayla, yazarlar sıralı olarak.
  /// Başlığı boş kitaplar anahtar üretemez; yalnız ISBN ile eşleşir.
  String? _titleAuthorKey(BookModel book) {
    final title = TextNormalizer.searchKey(book.title.trim());
    if (title.isEmpty) return null;
    final authors = book.authors
        .map((a) => TextNormalizer.searchKey(a.trim()))
        .where((a) => a.isNotEmpty)
        .toList()
      ..sort();
    return '$title|${authors.join(',')}';
  }
}

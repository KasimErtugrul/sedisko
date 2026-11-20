import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/datasources/book_local_datasource.dart';
import 'package:kitaplik/data/datasources/loan_local_datasource.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/datasources/wishlist_local_datasource.dart';
import 'package:kitaplik/data/models/backup_model.dart';
import 'package:kitaplik/data/models/borrowed_book_model.dart';
import 'package:kitaplik/data/models/loan_model.dart';
import 'package:kitaplik/data/models/wishlist_item_model.dart';
import 'package:kitaplik/data/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1.18.0 yedek zarfının yeni blokları: ödünç verilenler, ödünç alınanlar
/// ve satın alma listesi. Sürüm 2 dosyası uştan uca taşınır; sürüm 1
/// dosyası bu bloklarsız okunur (boş liste), bozuk tek kayıt dosyayı
/// geçersiz kılar (kitap/raf disipliniyle aynı).
void main() {
  LoanModel loan(String id, {String bookTitle = 'Kitap A'}) => LoanModel(
        id: id,
        bookId: 'book-$id',
        bookTitle: bookTitle,
        person: 'Ayşe',
        note: id == 'l2' ? 'acele değil' : null,
        lentAt: DateTime(2026, 11, 10, 15, 30),
      );

  BorrowedBookModel borrowed(String id) => BorrowedBookModel(
        id: id,
        title: 'Başkasının kitabı $id',
        authors: const ['Ali Veli'],
        owner: 'Mehmet',
        borrowedAt: DateTime(2026, 11, 12),
      );

  WishlistItemModel wish(String id, {String? isbn, String title = 'Alınacak'}) =>
      WishlistItemModel(
        id: id,
        title: title,
        authors: const ['Yazar Y'],
        isbn: isbn,
        addedAt: DateTime(2026, 11, 15),
        source: WishlistSource.openlibrary,
      );

  BackupEnvelope envelope({
    List<LoanModel> loans = const [],
    List<BorrowedBookModel> borrowed = const [],
    List<WishlistItemModel> wishlist = const [],
  }) =>
      BackupEnvelope(
        exportedAt: DateTime(2026, 11, 20, 9, 0),
        appVersion: '1.18.0',
        books: const [],
        shelves: const [],
        loans: loans,
        borrowed: borrowed,
        wishlist: wishlist,
      );

  group('BackupEnvelope v2 — yeni bloklar', () {
    test('ödünc ve satın alma kayıtları uştan uca taşınır', () {
      final raw = envelope(
        loans: [loan('l1'), loan('l2')],
        borrowed: [borrowed('b1')],
        wishlist: [wish('w1', isbn: '9780140328721')],
      ).encode();

      final result = BackupEnvelope.parse(raw);
      expect(result.isSuccess, isTrue);
      expect(result.envelope!.loans.length, 2);
      expect(result.envelope!.loans[0].person, 'Ayşe');
      expect(result.envelope!.loans[1].note, 'acele değil');
      expect(result.envelope!.borrowed.single.owner, 'Mehmet');
      expect(result.envelope!.wishlist.single.isbn, '9780140328721');
      expect(result.envelope!.wishlist.single.source,
          WishlistSource.openlibrary);
    });

    test('sürüm 1 dosyası (blok anahtarları yok) boş listelerle okunur', () {
      const v1 = '{"format":"kitapligim-yedek","formatVersion":1,'
          '"exportedAt":"2026-01-01T10:00:00.000","appVersion":"1.14.0",'
          '"books":[],"shelves":[]}';
      final result = BackupEnvelope.parse(v1);
      expect(result.isSuccess, isTrue);
      expect(result.envelope!.loans, isEmpty);
      expect(result.envelope!.borrowed, isEmpty);
      expect(result.envelope!.wishlist, isEmpty);
    });

    test('bozuk TEK ödünç kaydı tüm dosyayı geçersiz kılar', () {
      final raw = envelope(loans: [loan('l1'), loan('')]).encode();
      final result = BackupEnvelope.parse(raw);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('ödünç'));
    });

    test('bozuk satın alma kaydı dosyayı geçersiz kılar', () {
      final raw = envelope(wishlist: [wish('w1'), wish('', title: '')]).encode();
      final result = BackupEnvelope.parse(raw);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('satın alma'));
    });

    test('ödünc bloğu liste değilse dosya geçersizdir', () {
      final result = BackupEnvelope.parse(
          '{"format":"kitapligim-yedek","formatVersion":2,'
          '"books":[],"shelves":[],"loans":"bozuk"}');
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('ödünç'));
    });
  });

  group('BackupService — ödunc/satın alma depolarıyla', () {
    late BookLocalDataSource bookStore;
    late ShelfLocalDataSource shelfStore;
    late LoanLocalDataSource loanStore;
    late WishlistLocalDataSource wishlistStore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      bookStore = BookLocalDataSource(prefs);
      shelfStore = ShelfLocalDataSource(prefs);
      loanStore = LoanLocalDataSource(prefs);
      wishlistStore = WishlistLocalDataSource(prefs);
    });

    BackupService service() => BackupService(
          bookStore: bookStore,
          shelfStore: shelfStore,
          loanStore: loanStore,
          wishlistStore: wishlistStore,
        );

    test('buildEnvelope ödunc/satın alma kayıtlarını da toplar', () async {
      await loanStore.upsertLoan(loan('l1'));
      await loanStore.upsertBorrowed(borrowed('b1'));
      await wishlistStore.upsert(wish('w1'));

      final env = service().buildEnvelope();
      expect(env.loans.single.id, 'l1');
      expect(env.borrowed.single.id, 'b1');
      expect(env.wishlist.single.id, 'w1');
    });

    test('üzerine yaz: ödünc/satın alma listeleri komple değişir', () async {
      await loanStore.upsertLoan(loan('eski'));
      await wishlistStore.upsert(wish('eski-wish'));

      final summary = await service().applyImport(
        envelope(
          loans: [loan('yeni1'), loan('yeni2')],
          borrowed: [borrowed('yeni-b')],
          wishlist: [wish('yeni-w')],
        ),
        BackupImportMode.replace,
      );

      expect(loanStore.getLoans().map((l) => l.id), ['yeni1', 'yeni2']);
      expect(loanStore.getBorrowed().single.id, 'yeni-b');
      expect(wishlistStore.getItems().single.id, 'yeni-w');
      expect(summary.loansImported, 2);
      expect(summary.borrowedImported, 1);
      expect(summary.wishlistImported, 1);
    });

    test('birleştir: kimlik eşleşen ödunc atlanır, yeniler eklenir',
        () async {
      await loanStore.upsertLoan(loan('l1'));
      await wishlistStore.upsert(wish('w1', isbn: '9780140328721'));

      final summary = await service().applyImport(
        envelope(
          loans: [loan('l1'), loan('l2')],
          borrowed: [borrowed('b1')],
          wishlist: [
            wish('w1', isbn: '9780140328721'),
            wish('w2', isbn: '9780451524935', title: 'Farklı kitap'),
          ],
        ),
        BackupImportMode.merge,
      );

      expect(loanStore.getLoans().map((l) => l.id), ['l1', 'l2']);
      expect(loanStore.getBorrowed().single.id, 'b1');
      // ISBN eşleşen satın alma kaydı atlanır, yenisi eklenir.
      expect(wishlistStore.getItems().map((w) => w.id), ['w1', 'w2']);
      expect(summary.loansImported, 1);
      expect(summary.borrowedImported, 1);
      expect(summary.wishlistImported, 1);
    });

    test('depolar verilmezse ödunc/satın alma dokunulmaz kalır', () async {
      await loanStore.upsertLoan(loan('dokunma'));
      final plain = BackupService(bookStore: bookStore, shelfStore: shelfStore);
      await plain.applyImport(
        envelope(loans: [loan('l1')]),
        BackupImportMode.replace,
      );
      expect(loanStore.getLoans().single.id, 'dokunma');
    });
  });
}

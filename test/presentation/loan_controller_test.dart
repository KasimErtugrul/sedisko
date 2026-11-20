import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/errors/app_exceptions.dart';
import 'package:kitaplik/data/datasources/loan_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/borrowed_book_model.dart';
import 'package:kitaplik/data/models/loan_model.dart';
import 'package:kitaplik/presentation/controllers/loan_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yazmada hata fırlatan depo; kullanıcı bildirimi yolunu test eder.
class _ThrowingStore extends LoanLocalDataSource {
  _ThrowingStore(super.prefs, {this.failLoanWrites = false});

  final bool failLoanWrites;

  @override
  Future<void> upsertLoan(LoanModel loan) async {
    if (failLoanWrites) {
      throw const StorageException('Disk dolu');
    }
    return super.upsertLoan(loan);
  }
}

void main() {
  late LoanLocalDataSource store;
  late List<String> notifications;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LoanLocalDataSource(prefs);
    notifications = [];
  });

  tearDown(() {
    Get.reset();
  });

  LoanController buildController({LoanLocalDataSource? customStore}) {
    return LoanController(
      store: customStore ?? store,
      onNotify: (title, message) => notifications.add('$title|$message'),
    );
  }

  BookModel book(String id, {String title = 'Dune'}) => BookModel(
        id: id,
        title: title,
        addedAt: DateTime(2026, 1, 1),
      );

  group('lendBook', () {
    test('yeni kayıt açar ve true döner', () async {
      final controller = buildController();

      final ok = await controller.lendBook(
        book('b1'),
        '  Ayşe  ',
        note: ' 2 haftada getirecek ',
      );

      expect(ok, isTrue);
      expect(controller.loans, hasLength(1));
      expect(controller.loans.single.person, 'Ayşe');
      expect(controller.loans.single.note, '2 haftada getirecek');
      expect(controller.loans.single.isActive, isTrue);
      // Depoya da yazıldı.
      expect(store.getLoans(), hasLength(1));
    });

    test('boş kişi reddedilir; hiçbir şey yazılmaz', () async {
      final controller = buildController();

      expect(await controller.lendBook(book('b1'), '   '), isFalse);
      expect(await controller.lendBook(book('b1'), ''), isFalse);
      expect(controller.loans, isEmpty);
      expect(store.getLoans(), isEmpty);
      expect(notifications, isEmpty); // sessizce reddedilir
    });

    test('aynı kitaba sürüyor ödünç varken yeni kayıt açılabilir', () async {
      final controller = buildController();

      await controller.lendBook(book('b1'), 'Ayşe');
      final ok = await controller.lendBook(book('b1'), 'Mehmet');

      expect(ok, isTrue);
      expect(controller.loans, hasLength(2));
      expect(controller.activeLoanFor('b1'), isNotNull);
      // Kayıtlar bağımsız: ikisi de sürüyor.
      expect(controller.activeLoans, hasLength(2));
    });

    test('not boşsa null olarak kaydedilir', () async {
      final controller = buildController();

      await controller.lendBook(book('b1'), 'Ayşe', note: '   ');

      expect(controller.loans.single.note, isNull);
    });
  });

  group('sıralama', () {
    test('activeLoans en yeni verilenden başlar', () async {
      await store.upsertLoan(LoanModel(
        id: 'eski',
        bookId: 'b1',
        bookTitle: 'A',
        person: 'Ali',
        lentAt: DateTime(2026, 1, 15),
      ));
      await store.upsertLoan(LoanModel(
        id: 'yeni',
        bookId: 'b2',
        bookTitle: 'B',
        person: 'Veli',
        lentAt: DateTime(2026, 2, 20),
      ));

      final controller = buildController();
      await controller.load();

      expect(controller.activeLoans.map((l) => l.id).toList(),
          ['yeni', 'eski']);
    });

    test('returnedLoans en yeni geri alından başlar', () async {
      await store.upsertLoan(LoanModel(
        id: 'r1',
        bookId: 'b1',
        bookTitle: 'A',
        person: 'Ali',
        lentAt: DateTime(2026, 1, 1),
        returnedAt: DateTime(2026, 1, 10),
      ));
      await store.upsertLoan(LoanModel(
        id: 'r2',
        bookId: 'b2',
        bookTitle: 'B',
        person: 'Veli',
        lentAt: DateTime(2026, 1, 1),
        returnedAt: DateTime(2026, 2, 10),
      ));

      final controller = buildController();
      await controller.load();

      expect(controller.returnedLoans.map((l) => l.id).toList(), ['r2', 'r1']);
    });

    test('activeBorrowed en yeni alımdan başlar (depodan yüklerken)', () async {
      await store.upsertBorrowed(BorrowedBookModel(
        id: 'eski',
        title: 'Eski',
        owner: 'Can',
        borrowedAt: DateTime(2026, 1, 15),
      ));
      await store.upsertBorrowed(BorrowedBookModel(
        id: 'yeni',
        title: 'Yeni',
        owner: 'Veli',
        borrowedAt: DateTime(2026, 2, 20),
      ));

      final controller = buildController();
      await controller.load();

      expect(controller.activeBorrowed.map((b) => b.title).toList(),
          ['Yeni', 'Eski']);
    });

    test('aynı alım tarihinde son eklenen önce gösterilir', () async {
      // Windows flake regresyonu (1.19.1): DateTime.now() iki çağrıda
      // aynı değeri döndüğünde bile sıra deterministiktir — listedeki
      // konumu büyük (son eklenen) kayıt önce gösterilir.
      final at = DateTime(2026, 3, 10, 14, 30);
      await store.upsertBorrowed(BorrowedBookModel(
        id: 'bir',
        title: 'Bir',
        owner: 'Can',
        borrowedAt: at,
      ));
      await store.upsertBorrowed(BorrowedBookModel(
        id: 'iki',
        title: 'İki',
        owner: 'Veli',
        borrowedAt: at,
      ));

      final controller = buildController();
      await controller.load();

      expect(controller.activeBorrowed.map((b) => b.title).toList(),
          ['İki', 'Bir']);
    });

    test('aynı verilme tarihinde son eklenen ödünç önce gösterilir', () async {
      final at = DateTime(2026, 4, 1, 9, 0);
      await store.upsertLoan(LoanModel(
        id: 'bir',
        bookId: 'b1',
        bookTitle: 'A',
        person: 'Ali',
        lentAt: at,
      ));
      await store.upsertLoan(LoanModel(
        id: 'iki',
        bookId: 'b2',
        bookTitle: 'B',
        person: 'Veli',
        lentAt: at,
      ));

      final controller = buildController();
      await controller.load();

      expect(controller.activeLoans.map((l) => l.id).toList(), ['iki', 'bir']);
    });
  });

  group('markReturned', () {
    test('kaydı geri alınmış yapar ve depoya yazar', () async {
      final controller = buildController();
      await controller.lendBook(book('b1'), 'Ayşe');
      final loanId = controller.loans.single.id;

      final ok = await controller.markReturned(loanId);

      expect(ok, isTrue);
      expect(controller.loans.single.isActive, isFalse);
      expect(controller.loans.single.returnedAt, isNotNull);
      expect(controller.activeLoanFor('b1'), isNull);
      expect(controller.activeLoans, isEmpty);
      expect(controller.returnedLoans, hasLength(1));
      // Depodaki kayıt da güncel.
      expect(store.getLoans().single.isActive, isFalse);
    });

    test('bilinmeyen kimlikte false döner', () async {
      final controller = buildController();
      expect(await controller.markReturned('yok'), isFalse);
    });

    test('zaten geri alınmışsa idempotent true döner', () async {
      final controller = buildController();
      await controller.lendBook(book('b1'), 'Ayşe');
      final loanId = controller.loans.single.id;
      await controller.markReturned(loanId);
      final first = controller.loans.single.returnedAt;

      final ok = await controller.markReturned(loanId);

      expect(ok, isTrue);
      // İkinci çağrı tarihi değiştirmez.
      expect(controller.loans.single.returnedAt, first);
    });
  });

  group('removeLoan', () {
    test('bellekten ve depodan siler', () async {
      final controller = buildController();
      await controller.lendBook(book('b1'), 'Ayşe');
      final loanId = controller.loans.single.id;

      final ok = await controller.removeLoan(loanId);

      expect(ok, isTrue);
      expect(controller.loans, isEmpty);
      expect(store.getLoans(), isEmpty);
    });
  });

  group('addBorrowed', () {
    test('alıntı kaydı ekler ve yazarları temizler', () async {
      final controller = buildController();

      final ok = await controller.addBorrowed(
        title: ' Kürk Mantolu Madonna ',
        authors: [' Sabahattin Ali ', '', '  '],
        owner: ' Can ',
        note: ' okul kitabı ',
      );

      expect(ok, isTrue);
      final item = controller.borrowed.single;
      expect(item.title, 'Kürk Mantolu Madonna');
      expect(item.authors, ['Sabahattin Ali']);
      expect(item.owner, 'Can');
      expect(item.note, 'okul kitabı');
      expect(item.isActive, isTrue);
      expect(store.getBorrowed(), hasLength(1));
    });

    test('boş başlık ya da sahip reddedilir', () async {
      final controller = buildController();

      expect(
        await controller.addBorrowed(title: '   ', owner: 'Can'),
        isFalse,
      );
      expect(
        await controller.addBorrowed(title: 'X', owner: ''),
        isFalse,
      );
      expect(controller.borrowed, isEmpty);
      expect(store.getBorrowed(), isEmpty);
    });

    test('activeBorrowed en yeni alımdan başlar', () async {
      final controller = buildController();
      await controller.addBorrowed(title: 'Eski', owner: 'Can');
      await controller.addBorrowed(title: 'Yeni', owner: 'Veli');

      // Windows'ta saat çözünürlüğü kaba (~15 ms) olduğundan iki çağrı
      // aynı ana düşebilir; denetleyici eşitlikte son ekleneni önce
      // gösterir. Sonuç platformdan bağımsızdır (1.19.1 düzeltmesi).
      expect(controller.activeBorrowed.map((b) => b.title).toList(),
          ['Yeni', 'Eski']);
    });
  });

  group('updateBorrowed', () {
    test('mevcut kaydı günceller ve depoya yazar', () async {
      final controller = buildController();
      await controller.addBorrowed(title: 'X', owner: 'Can');
      final item = controller.borrowed.single;

      final ok = await controller.updateBorrowed(
        item.copyWith(title: 'X — 2. baskı'),
      );

      expect(ok, isTrue);
      expect(controller.borrowed.single.title, 'X — 2. baskı');
      expect(store.getBorrowed().single.title, 'X — 2. baskı');
    });

    test('bilinmeyen kimlikte ya da boş başlıkta false döner', () async {
      final controller = buildController();

      final fake = BorrowedBookModel(
        id: 'yok',
        title: 'Y',
        owner: 'Can',
        borrowedAt: fixedDate,
      );
      expect(await controller.updateBorrowed(fake), isFalse);

      await controller.addBorrowed(title: 'X', owner: 'Can');
      final item = controller.borrowed.single;
      expect(
        await controller.updateBorrowed(item.copyWith(title: '   ')),
        isFalse,
      );
    });
  });

  group('markBorrowedReturned / removeBorrowed', () {
    test('alıntıyı geri verilmiş yapar; remove siler', () async {
      final controller = buildController();
      await controller.addBorrowed(title: 'X', owner: 'Can');
      final id = controller.borrowed.single.id;

      final ok = await controller.markBorrowedReturned(id);

      expect(ok, isTrue);
      expect(controller.borrowed.single.isActive, isFalse);
      expect(controller.activeBorrowed, isEmpty);
      expect(controller.returnedBorrowed, hasLength(1));

      expect(await controller.removeBorrowed(id), isTrue);
      expect(controller.borrowed, isEmpty);
      expect(store.getBorrowed(), isEmpty);
    });

    test('bilinmeyen kimlikte false döner', () async {
      final controller = buildController();
      expect(await controller.markBorrowedReturned('yok'), isFalse);
      expect(await controller.removeBorrowed('yok'), isTrue);
    });
  });

  group('depolama hatası', () {
    test('kullanıcıya Kaydedilemedi bildirilir, false döner', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = buildController(
        customStore: _ThrowingStore(prefs, failLoanWrites: true),
      );

      final ok = await controller.lendBook(book('b1'), 'Ayşe');

      expect(ok, isFalse);
      expect(controller.loans, isEmpty); // bellek güncellenmez
      expect(notifications, isNotEmpty);
      expect(notifications.first, startsWith('Kaydedilemedi'));
    });
  });

  group('load', () {
    test('depodaki kayıtları belleğe yükler', () async {
      await store.upsertLoan(LoanModel(
        id: 'l1',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ayşe',
        lentAt: DateTime(2026, 2, 20),
      ));
      final item = BorrowedBookModel(
        id: 'bb1',
        title: 'X',
        owner: 'Can',
        borrowedAt: fixedDate,
      );
      await store.upsertBorrowed(item);

      final controller = buildController();
      await controller.load();

      expect(controller.loans, hasLength(1));
      expect(controller.borrowed, hasLength(1));
      expect(controller.activeLoanFor('b1')?.id, 'l1');
    });
  });
}

/// Sabit tarih; test verisinin okunabilirliği için.
final DateTime fixedDate = DateTime(2026, 2, 10);

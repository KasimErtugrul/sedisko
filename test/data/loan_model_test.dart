import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/borrowed_book_model.dart';
import 'package:kitaplik/data/models/loan_model.dart';

/// Ödünç modelleri (1.18.0): JSON dönüşümü, savunmacı ayrıştırma ve
/// copyWith sentinel davranışı.
void main() {
  group('LoanModel', () {
    test('toJson/fromJson turunu kayıpsız tamamlar', () {
      final loan = LoanModel(
        id: 'l1',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ayşe',
        note: '2 haftada getirecek',
        lentAt: DateTime(2026, 2, 20, 10, 30),
        returnedAt: DateTime(2026, 3, 5, 18, 0),
      );

      final restored = LoanModel.tryFromJson(loan.toJson());

      expect(restored, loan);
      expect(restored!.note, '2 haftada getirecek');
      expect(restored.returnedAt, DateTime(2026, 3, 5, 18, 0));
    });

    test('fromJson aynı turu tamamlar', () {
      final loan = LoanModel(
        id: 'l2',
        bookId: 'b1',
        bookTitle: 'Sefiller',
        person: 'Mehmet',
        lentAt: DateTime(2026, 1, 15),
      );

      final restored = LoanModel.fromJson(loan.toJson());

      expect(restored, loan);
      expect(restored.isActive, isTrue);
    });

    test('tryFromJson bozuk/eksik kayıtlarda null döner', () {
      // Zorunlu alanlar.
      expect(
        LoanModel.tryFromJson(const {
          'bookId': 'b1',
          'bookTitle': 'Dune',
          'person': 'Ayşe',
          'lentAt': '2026-02-20T10:30:00.000',
        }),
        isNull,
      );
      expect(
        LoanModel.tryFromJson(const {
          'id': '',
          'bookId': 'b1',
          'bookTitle': 'Dune',
          'person': 'Ayşe',
          'lentAt': '2026-02-20T10:30:00.000',
        }),
        isNull,
      );
      expect(
        LoanModel.tryFromJson(const {
          'id': 'l1',
          'bookId': 'b1',
          'bookTitle': 'Dune',
          'person': '',
          'lentAt': '2026-02-20T10:30:00.000',
        }),
        isNull,
      );
      // Tarihler.
      expect(
        LoanModel.tryFromJson(const {
          'id': 'l1',
          'bookId': 'b1',
          'bookTitle': 'Dune',
          'person': 'Ayşe',
        }),
        isNull,
      );
      expect(
        LoanModel.tryFromJson(const {
          'id': 'l1',
          'bookId': 'b1',
          'bookTitle': 'Dune',
          'person': 'Ayşe',
          'lentAt': 'tarih-degil',
        }),
        isNull,
      );
      // returnedAt verilmiş ama ayrıştırılamıyor: kayıt belirsiz → düşer.
      expect(
        LoanModel.tryFromJson(const {
          'id': 'l1',
          'bookId': 'b1',
          'bookTitle': 'Dune',
          'person': 'Ayşe',
          'lentAt': '2026-02-20T10:30:00.000',
          'returnedAt': 'bozuk-tarih',
        }),
        isNull,
      );
    });

    test('fromJson bozuk kayıtta FormatException fırlatır', () {
      expect(() => LoanModel.fromJson(const {}), throwsFormatException);
    });

    test('copyWith: verilmeyen alanlar korunur', () {
      final loan = LoanModel(
        id: 'l1',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ayşe',
        note: 'not',
        lentAt: DateTime(2026, 2, 20),
      );

      final same = loan.copyWith();

      expect(same, loan);
      expect(same.note, 'not');
      expect(same.returnedAt, isNull);
    });

    test('copyWith: null ile note/returnedAt temizlenir', () {
      final loan = LoanModel(
        id: 'l1',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ayşe',
        note: 'not',
        lentAt: DateTime(2026, 2, 20),
      );

      final clearedNote = loan.copyWith(note: null);
      expect(clearedNote.note, isNull);
      // Diğer alanlar korunur.
      expect(clearedNote.person, 'Ayşe');
      expect(clearedNote.lentAt, loan.lentAt);

      final returned = loan.copyWith(returnedAt: DateTime(2026, 3, 1));
      expect(returned.returnedAt, DateTime(2026, 3, 1));
      expect(returned.isActive, isFalse);

      final clearedReturn = returned.copyWith(returnedAt: null);
      expect(clearedReturn.returnedAt, isNull);
      expect(clearedReturn.isActive, isTrue);
    });

    test('isActive: returnedAt null iken sürer', () {
      final active = LoanModel(
        id: 'l1',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ayşe',
        lentAt: DateTime(2026, 2, 20),
      );
      expect(active.isActive, isTrue);

      final returned = active.copyWith(returnedAt: DateTime(2026, 3, 1));
      expect(returned.isActive, isFalse);
    });

    test('newId çakışmayan kimlik üretir', () {
      final ids = {for (var i = 0; i < 50; i++) LoanModel.newId()};
      expect(ids.length, 50);
    });
  });

  group('BorrowedBookModel', () {
    test('toJson/fromJson turunu kayıpsız tamamlar', () {
      final item = BorrowedBookModel(
        id: 'bb1',
        title: 'Kürk Mantolu Madonna',
        authors: ['Sabahattin Ali'],
        owner: 'Can',
        note: 'okul kitabı',
        borrowedAt: DateTime(2026, 2, 10),
        returnedAt: DateTime(2026, 3, 1),
      );

      final restored = BorrowedBookModel.tryFromJson(item.toJson());

      expect(restored, item);
      expect(restored!.authors, ['Sabahattin Ali']);
      expect(restored.authorsText, 'Sabahattin Ali');
    });

    test('tryFromJson bozuk kayıtlarda null döner', () {
      expect(BorrowedBookModel.tryFromJson(const {}), isNull);
      expect(
        BorrowedBookModel.tryFromJson(const {'id': 'bb1', 'title': ''}),
        isNull,
      );
      expect(
        BorrowedBookModel.tryFromJson(
          const {'id': 'bb1', 'title': 'X', 'owner': ''},
        ),
        isNull,
      );
      expect(
        BorrowedBookModel.tryFromJson(
          const {'id': 'bb1', 'title': 'X', 'owner': 'Can', 'borrowedAt': 'x'},
        ),
        isNull,
      );
    });

    test('authors savunmacı ayrıştırılır; eksik alanlar varsayılan gelir',
        () {
      final item = BorrowedBookModel.tryFromJson(const {
        'id': 'bb1',
        'title': 'X',
        'owner': 'Can',
        'borrowedAt': '2026-02-10T00:00:00.000',
        'authors': ['A', 2, '', 'B'],
        'note': '',
      });
      expect(item, isNotNull);
      expect(item!.authors, ['A', '2', 'B']);
      expect(item.note, isNull);
      expect(item.returnedAt, isNull);
      expect(item.isActive, isTrue);
    });

    test('copyWith: null ile note temizlenir, verilmeyen korunur', () {
      final item = BorrowedBookModel(
        id: 'bb1',
        title: 'X',
        owner: 'Can',
        note: 'not',
        borrowedAt: DateTime(2026, 2, 10),
      );

      final same = item.copyWith();
      expect(same, item);
      expect(same.note, 'not');

      final cleared = item.copyWith(note: null);
      expect(cleared.note, isNull);

      final returned = item.copyWith(returnedAt: DateTime(2026, 3, 1));
      expect(returned.isActive, isFalse);
    });
  });
}

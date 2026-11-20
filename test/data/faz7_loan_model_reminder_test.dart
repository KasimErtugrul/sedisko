import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/borrowed_book_model.dart';
import 'package:kitaplik/data/models/loan_model.dart';

/// Keşke 34/35 (1.26.0): ödünç kayıtlarına hatırlatma günü eklendi.
/// Modelin savunmacı sözleşmesi korunur: alan eski veride hiç yoktur
/// (null), bozuk tarih kaydı ATMAMALIDIR; JSON turu kaybızsızdır.
void main() {
  group('LoanModel.dueAt (keşke 34)', () {
    final lent = DateTime(2026, 11, 20, 10);
    final due = DateTime(2026, 11, 27, 9);

    test('dueAt ile kurulan kayıt JSON turunu kayıpsız geçirir', () {
      final loan = LoanModel(
        id: 'l1',
        bookId: 'b1',
        bookTitle: 'Dune',
        person: 'Ayşe',
        lentAt: lent,
        dueAt: due,
      );

      final json = loan.toJson();
      expect(json['dueAt'], due.toIso8601String());

      final parsed = LoanModel.tryFromJson(json);
      expect(parsed, isNotNull);
      expect(parsed!.dueAt, due);
      expect(parsed.isActive, isTrue);
    });

    test('eski kayıtta dueAt hiç yoktur; null okunur', () {
      // 1.25.0 yedeğinden kalan kayıt: dueAt alanı YOK.
      final old = <String, dynamic>{
        'id': 'l2',
        'bookId': 'b2',
        'bookTitle': 'Simyacı',
        'person': 'Mehmet',
        'note': null,
        'lentAt': lent.toIso8601String(),
        'returnedAt': null,
      };

      final parsed = LoanModel.tryFromJson(old);
      expect(parsed, isNotNull);
      expect(parsed!.dueAt, isNull);
    });

    test('bozuk dueAt hatırlatmayı düşürür ama kaydı ATMAMAZ', () {
      final broken = <String, dynamic>{
        'id': 'l3',
        'bookId': 'b3',
        'bookTitle': 'Kürk Mantolu Madonna',
        'person': 'Zeynep',
        'lentAt': lent.toIso8601String(),
        'dueAt': 'yarın',
      };

      final parsed = LoanModel.tryFromJson(broken);
      expect(parsed, isNotNull);
      expect(parsed!.dueAt, isNull);
      expect(parsed.person, 'Zeynep');
    });

    test('copyWith dueAt temizler; verilmezse eski değer korunur', () {
      final loan = LoanModel(
        id: 'l4',
        bookId: 'b4',
        bookTitle: 'Tutunamayanlar',
        person: 'Can',
        lentAt: lent,
        dueAt: due,
      );

      // Alan verilmez: korunur.
      final same = loan.copyWith(returnedAt: DateTime(2026, 11, 25));
      expect(same.dueAt, due);

      // null verilir: temizlenir.
      final cleared = loan.copyWith(dueAt: null);
      expect(cleared.dueAt, isNull);
    });
  });

  group('BorrowedBookModel.remindAt (keşke 35)', () {
    final borrowedAt = DateTime(2026, 11, 1, 12);
    final remindAt = DateTime(2026, 11, 15, 9);

    test('remindAt ile kurulan kayıt JSON turunu kayıpsız geçirir', () {
      final item = BorrowedBookModel(
        id: 'bo1',
        title: 'Beyaz Kale',
        authors: ['Orhan Pamuk'],
        owner: 'Komşu Ahmet',
        borrowedAt: borrowedAt,
        remindAt: remindAt,
      );

      final json = item.toJson();
      expect(json['remindAt'], remindAt.toIso8601String());

      final parsed = BorrowedBookModel.tryFromJson(json);
      expect(parsed, isNotNull);
      expect(parsed!.remindAt, remindAt);
    });

    test('eski kayıtta remindAt hiç yoktur; null okunur', () {
      final old = <String, dynamic>{
        'id': 'bo2',
        'title': 'Şeker Portakalı',
        'authors': ['Jose Mauro de Vasconcelos'],
        'owner': 'Elif',
        'borrowedAt': borrowedAt.toIso8601String(),
      };

      final parsed = BorrowedBookModel.tryFromJson(old);
      expect(parsed, isNotNull);
      expect(parsed!.remindAt, isNull);
    });

    test('bozuk remindAt hatırlatmayı düşürür ama kaydı ATMAMAZ', () {
      final broken = <String, dynamic>{
        'id': 'bo3',
        'title': 'Yaban',
        'owner': 'Halit',
        'borrowedAt': borrowedAt.toIso8601String(),
        'remindAt': 12345,
      };

      final parsed = BorrowedBookModel.tryFromJson(broken);
      expect(parsed, isNotNull);
      expect(parsed!.remindAt, isNull);
      expect(parsed.owner, 'Halit');
    });
  });
}

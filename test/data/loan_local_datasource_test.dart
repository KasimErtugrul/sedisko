import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/datasources/loan_local_datasource.dart';
import 'package:kitaplik/data/models/borrowed_book_model.dart';
import 'package:kitaplik/data/models/loan_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ödünç deposu (loans_v1 / borrowed_v1): kaydetme-okuma-silme turu,
/// savunmacı blok okuma ve sıralı yazma davranışı.
LoanModel loan(String id, {DateTime? lentAt, DateTime? returnedAt}) =>
    LoanModel(
      id: id,
      bookId: 'b1',
      bookTitle: 'Dune',
      person: 'Ayşe',
      lentAt: lentAt ?? DateTime(2026, 2, 20),
      returnedAt: returnedAt,
    );

void main() {
  group('loans_v1', () {
    test('ödünç kaydı eklenir, okunur ve güncellenir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LoanLocalDataSource(prefs);

      await store.upsertLoan(loan('l1'));
      await store.upsertLoan(loan('l2', lentAt: DateTime(2026, 3, 1)));

      var loans = store.getLoans();
      expect(loans, hasLength(2));

      // Aynı kimlikle ikinci upsert: kaydı günceller, çoğaltmaz.
      await store.upsertLoan(
        loan('l1', returnedAt: DateTime(2026, 3, 10)),
      );
      loans = store.getLoans();
      expect(loans, hasLength(2));
      expect(
        loans.firstWhere((l) => l.id == 'l1').returnedAt,
        DateTime(2026, 3, 10),
      );
    });

    test('ödünç kaydı silinir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LoanLocalDataSource(prefs);

      await store.upsertLoan(loan('l1'));
      await store.removeLoan('l1');

      expect(store.getLoans(), isEmpty);
    });

    test('upsert sonra remove: iki yazma sırayla uygulanır', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LoanLocalDataSource(prefs);

      // Kuyruğa alınmış iki yazma; ikincisi ilkincinin üzerine geçmez.
      await store.upsertLoan(loan('l1'));
      await store.removeLoan('l1');

      final raw = prefs.getString('loans_v1');
      expect(raw, isNotNull);
      expect(jsonDecode(raw!), isEmpty);
      expect(store.getLoans(), isEmpty);
    });

    test('bozuk blok boş liste döner', () async {
      SharedPreferences.setMockInitialValues({'loans_v1': '[[[['});
      final prefs = await SharedPreferences.getInstance();
      expect(LoanLocalDataSource(prefs).getLoans(), isEmpty);
    });

    test('blok liste değilse boş liste döner', () async {
      SharedPreferences.setMockInitialValues({'loans_v1': '{"id":"l1"}'});
      final prefs = await SharedPreferences.getInstance();
      expect(LoanLocalDataSource(prefs).getLoans(), isEmpty);
    });

    test('bozuk tek kayıt atlanır, sağlamlar korunur', () async {
      SharedPreferences.setMockInitialValues({
        'loans_v1': jsonEncode([
          loan('l1').toJson(),
          // person boş: bozuk.
          {'id': 'l2', 'bookId': 'b1', 'bookTitle': 'X', 'person': ''},
          // lentAt bozuk: bozuk.
          {
            'id': 'l3',
            'bookId': 'b1',
            'bookTitle': 'X',
            'person': 'Veli',
            'lentAt': 'bozuk',
          },
          loan('l4', lentAt: DateTime(2026, 1, 1)).toJson(),
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      final loans = LoanLocalDataSource(prefs).getLoans();

      expect(loans.map((l) => l.id).toList(), ['l1', 'l4']);
    });

    test('anahtar hiç yoksa boş liste döner', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(LoanLocalDataSource(prefs).getLoans(), isEmpty);
    });
  });

  group('borrowed_v1', () {
    test('alıntı kaydı eklenir, okunur, güncellenir ve silinir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LoanLocalDataSource(prefs);

      final item = BorrowedBookModel(
        id: 'bb1',
        title: 'Kürk Mantolu Madonna',
        authors: ['Sabahattin Ali'],
        owner: 'Can',
        borrowedAt: DateTime(2026, 2, 10),
      );

      await store.upsertBorrowed(item);
      expect(store.getBorrowed().single, item);

      await store.upsertBorrowed(
        item.copyWith(returnedAt: DateTime(2026, 3, 1)),
      );
      var loaded = store.getBorrowed();
      expect(loaded, hasLength(1));
      expect(loaded.single.returnedAt, DateTime(2026, 3, 1));

      await store.removeBorrowed('bb1');
      loaded = store.getBorrowed();
      expect(loaded, isEmpty);
    });

    test('bozuk tek alıntı kaydı atlanır', () async {
      SharedPreferences.setMockInitialValues({
        'borrowed_v1': jsonEncode([
          {'id': '', 'title': 'Bozuk', 'owner': 'X'},
          {
            'id': 'bb1',
            'title': 'Sağlam',
            'owner': 'Can',
            'borrowedAt': '2026-02-10T00:00:00.000',
          },
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      final items = LoanLocalDataSource(prefs).getBorrowed();

      expect(items.map((b) => b.id).toList(), ['bb1']);
    });

    test('bozuk alıntı bloğu boş liste döner', () async {
      SharedPreferences.setMockInitialValues({'borrowed_v1': 'not-json'});
      final prefs = await SharedPreferences.getInstance();
      expect(LoanLocalDataSource(prefs).getBorrowed(), isEmpty);
    });
  });
}

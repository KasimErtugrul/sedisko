import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/borrowed_book_model.dart';
import '../models/loan_model.dart';

/// Ödünç kayıtlarının kalıcı deposu (1.18.0).
///
/// İki bağımsız JSON listesi tutar:
/// - [StorageKeys.loans] (`loans_v1`): kitaplıkta verdiğimiz kitaplar.
/// - [StorageKeys.borrowed] (`borrowed_v1`): başkasından aldığımız
///   kitaplar (kitaplık kaydı değildir; sahibi başkasıdır).
///
/// Güvenlik notları (bkz. `BookLocalDataSource`):
/// - Bozuk *tek* kayıt tüm listeyi silmez; geçerli kayıtlar korunur.
/// - Bozuk *blok* boş liste döner; yazma üzerine sağlıklı veri yazar.
/// - Okuma-güncelleme-yazma döngüsü sıraya alınır (_lock); paralel iki
///   yazma birbirinin üstüne yazmaz (lost-update problemi).
class LoanLocalDataSource {
  LoanLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Sıraya alınmış yazma işlemleri (ödünç verilen ve alınan kayıtlar
  /// aynı kiliti paylaşır: iki anahtar birden tutarlı kalır).
  Future<void>? _lock;

  List<LoanModel> getLoans() {
    return _readList(StorageKeys.loans, LoanModel.tryFromJson);
  }

  Future<void> upsertLoan(LoanModel loan) {
    return _runSerialized(() async {
      final loans = getLoans();
      final index = loans.indexWhere((l) => l.id == loan.id);
      if (index >= 0) {
        loans[index] = loan;
      } else {
        loans.add(loan);
      }
      await _write(loans.map((l) => l.toJson()).toList(), StorageKeys.loans,
          'Ödünç kaydı kaydedilemedi. Depolama alanını kontrol edin.');
    });
  }

  Future<void> removeLoan(String id) {
    return _runSerialized(() async {
      final loans = getLoans()..removeWhere((l) => l.id == id);
      await _write(loans.map((l) => l.toJson()).toList(), StorageKeys.loans,
          'Ödünç kaydı silinemedi. Depolama alanını kontrol edin.');
    });
  }

  /// "Üzerine yaz" içe aktarması: ödünç listesini komple değiştirir.
  /// Yalnızca yedek dosyası uçtan uca doğrulandıktan sonra çağrılmalıdır.
  Future<void> replaceAllLoans(List<LoanModel> loans) {
    return _runSerialized(() async {
      await _write(
        loans.map((l) => l.toJson()).toList(),
        StorageKeys.loans,
        'Ödünç kayıtları geri yüklenemedi. Depolama alanını kontrol edin.',
      );
    });
  }

  List<BorrowedBookModel> getBorrowed() {
    return _readList(StorageKeys.borrowed, BorrowedBookModel.tryFromJson);
  }

  Future<void> upsertBorrowed(BorrowedBookModel item) {
    return _runSerialized(() async {
      final items = getBorrowed();
      final index = items.indexWhere((b) => b.id == item.id);
      if (index >= 0) {
        items[index] = item;
      } else {
        items.add(item);
      }
      await _write(
        items.map((b) => b.toJson()).toList(),
        StorageKeys.borrowed,
        'Ödünç aldığın kitap kaydedilemedi. Depolama alanını kontrol edin.',
      );
    });
  }

  Future<void> removeBorrowed(String id) {
    return _runSerialized(() async {
      final items = getBorrowed()..removeWhere((b) => b.id == id);
      await _write(
        items.map((b) => b.toJson()).toList(),
        StorageKeys.borrowed,
        'Ödünç aldığın kitap silinemedi. Depolama alanını kontrol edin.',
      );
    });
  }

  /// "Üzerine yaz" içe aktarması: ödünç alınan listesini komple değiştirir.
  Future<void> replaceAllBorrowed(List<BorrowedBookModel> items) {
    return _runSerialized(() async {
      await _write(
        items.map((b) => b.toJson()).toList(),
        StorageKeys.borrowed,
        'Ödünç aldığın kitaplar geri yüklenemedi. '
            'Depolama alanını kontrol edin.',
      );
    });
  }

  /// Savunmacı blok okuma: bozuk blok boş liste, bozuk tek kayıt atlanır.
  List<T> _readList<T>(
    String key,
    T? Function(Map<String, dynamic> json) parse,
  ) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> list;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      list = decoded;
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }

    final items = <T>[];
    for (final item in list) {
      if (item is! Map) continue;
      final parsed = parse(Map<String, dynamic>.from(item));
      if (parsed != null) items.add(parsed);
    }
    return items;
  }

  Future<void> _runSerialized(Future<void> Function() action) {
    final previous = _lock ?? Future<void>.value();
    final task = previous.catchError((Object _) {}).then((_) => action());
    // Bir işlem hata verirse kuyruk bozulmasın: hatayı yut, sıradaki işlem
    // yine de çalışabilsin. Hata, çağırana [task] üzerinden iletilir.
    _lock = task.catchError((Object _) {});
    return task;
  }

  Future<void> _write(List<Map<String, dynamic>> json, String key,
      String failureMessage) async {
    final encoded = jsonEncode(json);
    try {
      final ok = await _prefs.setString(key, encoded);
      if (!ok) {
        throw StorageException(failureMessage);
      }
    } on StorageException {
      rethrow;
    } catch (error) {
      throw StorageException(failureMessage, cause: error);
    }
  }
}

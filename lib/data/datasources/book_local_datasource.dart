import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/book_model.dart';

/// Tüm kitaplar tek bir JSON listesi olarak SharedPreferences'ta tutulur.
///
/// Güvenlik notları:
/// - Bozuk *tek* kayıt tüm kitaplığı silmez; geçerli kayıtlar korunur.
/// - Okuma-güncelleme-yazma döngüsü sıraya alınır (_lock); paralel iki
///   kayıt birbirinin üstüne yazmaz (lost-update problemi).
class BookLocalDataSource {
  BookLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Sıraya alınmış yazma işlemleri.
  Future<void>? _lock;

  List<BookModel> getBooks() {
    final raw = _prefs.getString(StorageKeys.books);
    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> list;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      list = decoded;
    } on FormatException {
      // Tüm blok bozuksa kayıt yokmuş gibi davran; yazma sırasında
      // üzerine sağlıklı bir liste yazılacaktır.
      return [];
    } on TypeError {
      return [];
    }

    final books = <BookModel>[];
    for (final item in list) {
      if (item is! Map) continue;
      final book = BookModel.tryFromJson(Map<String, dynamic>.from(item));
      if (book != null) books.add(book);
    }
    return books;
  }

  Future<void> upsert(BookModel book) {
    return _runSerialized(() async {
      final books = getBooks();
      final index = books.indexWhere((b) => b.id == book.id);
      if (index >= 0) {
        books[index] = book;
      } else {
        books.add(book);
      }
      await _write(books);
    });
  }

  Future<void> delete(String id) {
    return _runSerialized(() async {
      final books = getBooks()..removeWhere((b) => b.id == id);
      await _write(books);
    });
  }

  /// Yedek içe aktarmada kullanılır: verilen kitapları mevcut listeye
  /// TEK okuma-yazma döngüsünde ekler (kitap başına liste yazmaz).
  Future<void> addMany(List<BookModel> books) {
    if (books.isEmpty) return Future<void>.value();
    return _runSerialized(() async {
      final all = getBooks()..addAll(books);
      await _write(all);
    });
  }

  /// "Üzerine yaz" içe aktarması: mevcut listeyi komple değiştirir.
  ///
  /// Yalnızca yedek dosyası uçtan uca doğrulandıktan ([BackupEnvelope.parse])
  /// sonra çağrılmalıdır; hatalı veri varsa listeyi boşaltmak yerine
  /// hiçbir şey yazmadan hata fırlatır.
  Future<void> replaceAll(List<BookModel> books) {
    return _runSerialized(() async => _write(books));
  }

  Future<void> _runSerialized(Future<void> Function() action) {
    final previous = _lock ?? Future<void>.value();
    final task = previous.catchError((Object _) {}).then((_) => action());
    // Bir işlem hata verirse kuyruk bozulmasın: hatayı yut, sıradaki işlem
    // yine de çalışabilsin. Hata, çağırana [task] üzerinden iletilir.
    _lock = task.catchError((Object _) {});
    return task;
  }

  Future<void> _write(List<BookModel> books) async {
    final encoded = jsonEncode(books.map((b) => b.toJson()).toList());
    try {
      final ok = await _prefs.setString(StorageKeys.books, encoded);
      if (!ok) {
        throw const StorageException(
          'Kitaplık kaydedilemedi. Depolama alanını kontrol edin.',
        );
      }
    } on StorageException {
      rethrow;
    } catch (error) {
      throw StorageException(
        'Kitaplık kaydedilemedi. Depolama alanını kontrol edin.',
        cause: error,
      );
    }
  }
}

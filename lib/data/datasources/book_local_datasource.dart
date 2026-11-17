import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/book_model.dart';

/// Tüm kitaplar tek bir JSON listesi olarak SharedPreferences'ta tutulur.
class BookLocalDataSource {
  BookLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  List<BookModel> getBooks() {
    final raw = _prefs.getString(StorageKeys.books);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => BookModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> upsert(BookModel book) async {
    final books = getBooks();
    final index = books.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      books[index] = book;
    } else {
      books.add(book);
    }
    await _write(books);
  }

  Future<void> delete(String id) async {
    final books = getBooks()..removeWhere((b) => b.id == id);
    await _write(books);
  }

  Future<void> _write(List<BookModel> books) async {
    final encoded = jsonEncode(books.map((b) => b.toJson()).toList());
    await _prefs.setString(StorageKeys.books, encoded);
  }
}

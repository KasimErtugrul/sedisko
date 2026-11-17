import '../../data/models/book_model.dart';

/// Entity ve usecase katmanı yok; domain yalnızca sözleşmeyi tanımlar.
abstract class BookRepository {
  Future<List<BookModel>> getBooks();

  Future<void> saveBook(BookModel book);

  Future<void> deleteBook(String id);

  /// Open Library'de bulunamazsa `null` döner.
  /// Ağ hatasında `NetworkException` fırlatır.
  Future<BookModel?> fetchBookByIsbn(String isbn);
}

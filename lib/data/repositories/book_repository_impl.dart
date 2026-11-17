import '../../domain/repositories/book_repository.dart';
import '../datasources/book_local_datasource.dart';
import '../datasources/open_library_remote_datasource.dart';
import '../models/book_model.dart';

class BookRepositoryImpl implements BookRepository {
  BookRepositoryImpl({
    required BookLocalDataSource local,
    required OpenLibraryRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final BookLocalDataSource _local;
  final OpenLibraryRemoteDataSource _remote;

  @override
  Future<List<BookModel>> getBooks() async => _local.getBooks();

  @override
  Future<void> saveBook(BookModel book) => _local.upsert(book);

  @override
  Future<void> deleteBook(String id) => _local.delete(id);

  @override
  Future<BookModel?> fetchBookByIsbn(String isbn) async {
    final data = await _remote.fetchByIsbn(isbn);
    if (data == null) return null;
    return BookModel.fromOpenLibrary(isbn.trim(), data);
  }
}

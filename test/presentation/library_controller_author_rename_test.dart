import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/core/errors/app_exceptions.dart';
import 'package:kitaplik/core/utils/text_normalizer.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/reading_log_entry.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';

class FakeBookRepository implements BookRepository {
  FakeBookRepository({List<BookModel>? initial, this.failSaveForId})
      : store = [...?initial];

  final List<BookModel> store;

  /// Bu kimlikteki kitabın kaydı bu hatayla başarısız olur (kısmi
  /// güncelleme testi için).
  final String? failSaveForId;

  @override
  Future<List<BookModel>> getBooks() async => [...store];

  @override
  Future<void> saveBook(BookModel book) async {
    if (book.id == failSaveForId) {
      throw const StorageException('Depo dolu');
    }
    final index = store.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      store[index] = book;
    } else {
      store.add(book);
    }
  }

  @override
  Future<void> deleteBook(String id) async =>
      store.removeWhere((b) => b.id == id);

  @override
  Future<BookModel?> fetchBookByIsbn(String isbn) async => null;
}

BookModel book(
  String id,
  String title,
  List<String> authors,
) =>
    BookModel(
      id: id,
      title: title,
      authors: authors,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  late FakeBookRepository repository;
  late LibraryController controller;

  setUp(() {
    Get.testMode = true;
    repository = FakeBookRepository(initial: [
      book('b1', 'Kasım Kitabı A', ['Kasım']),
      // Open Library sadeleştirmesi: aynı yazarın İngilizce yazımı.
      book('b2', 'Kasım Kitabı B', ['Kasim']),
      // Yan yazar korunmalı.
      book('b3', 'Kasım Kitabı C', ['Kasim', 'Orhan Pamuk']),
      // Aynı kitapta iki yazım birden: tek isimde birleşmeli.
      book('b4', 'Kasım Kitabı D', ['Kasım', 'Kasim']),
      book('b5', 'Başka Kitap', ['Ayşe Kulin']),
    ]);
    controller = LibraryController(repository, onNotify: (_, __) {});
    controller.books.assignAll(repository.store);
  });

  tearDown(() {
    Get.reset();
  });

  group('yazar kümeleme', () {
    test('Kasım ve Kasim tek kartta toplanır (arama anahtarı aynı)', () {
      final kasimCards = controller.authors
          .where((a) => TextNormalizer.searchKey(a) == 'kasim')
          .toList();

      expect(kasimCards, hasLength(1));
      // Görünen ad ilk görülen yazımdır (b1'in 'Kasım' yazımı).
      expect(kasimCards.single, 'Kasım');
    });

    test('authorSpellings tüm yazımları ilk görülme sırasıyla verir', () {
      expect(controller.authorSpellings('kasim'), ['Kasım', 'Kasim']);
    });

    test('gruba girmeyen anahtar boş yazım listesi verir', () {
      expect(controller.authorSpellings('yok'), isEmpty);
    });

    test('authorBookCount grup kitap sayısını verir', () {
      expect(controller.authorBookCount('kasim'), 4);
      expect(controller.authorBookCount(TextNormalizer.searchKey('Ayşe Kulin')),
          1);
      expect(controller.authorBookCount('yok'), 0);
    });
  });

  group('renameAuthor', () {
    test('tüm varyantları tek isimde birleştirir', () async {
      final changed = await controller.renameAuthor('kasim', 'Kasım');

      expect(changed, 4);
      expect(controller.byId('b1')!.authors, ['Kasım']);
      expect(controller.byId('b2')!.authors, ['Kasım']);
      // Yan yazar korunur, sırası bozulmaz.
      expect(controller.byId('b3')!.authors, ['Kasım', 'Orhan Pamuk']);
      // Aynı kitaptaki iki yazım tek isimde birleşir.
      expect(controller.byId('b4')!.authors, ['Kasım']);
      // İlgisiz kitap dokunulmaz.
      expect(controller.byId('b5')!.authors, ['Ayşe Kulin']);
    });

    test('depo da güncellenir', () async {
      await controller.renameAuthor('kasim', 'Kasım');

      expect(
        repository.store.firstWhere((b) => b.id == 'b2').authors,
        ['Kasım'],
      );
    });

    test('okuma günlüğü ve diğer alanlar korunur', () async {
      final index = repository.store.indexWhere((b) => b.id == 'b2');
      repository.store[index] = repository.store[index].copyWith(
        status: ReadingStatus.reading,
        currentPage: 40,
        pageCount: 100,
        readingLog: [ReadingLogEntry(at: DateTime(2026, 1, 2), page: 40)],
      );
      await controller.loadBooks();

      await controller.renameAuthor('kasim', 'Kasım');

      final b2 = controller.byId('b2')!;
      expect(b2.currentPage, 40);
      expect(b2.status, ReadingStatus.reading);
      // Günlük türetilmez; mevcut günlük aynen korunur (deriveLog: false).
      expect(b2.readingLog, hasLength(1));
      expect(b2.readingLog.single.page, 40);
    });

    test('farklı anahtara yeniden adlandırma yeni grup oluşturur', () async {
      await controller.renameAuthor('kasim', 'M. Kasım');

      expect(controller.byId('b1')!.authors, ['M. Kasım']);
      expect(
        controller.authorDisplayName(TextNormalizer.searchKey('M. Kasım')),
        'M. Kasım',
      );
      expect(controller.authorSpellings('kasim'), isEmpty);
      expect(
        controller
            .authorSpellings(TextNormalizer.searchKey('M. Kasım'))
            .single,
        'M. Kasım',
      );
    });

    test('boş isim hiçbir kitabı değiştirmez', () async {
      final changed = await controller.renameAuthor('kasim', '   ');

      expect(changed, 0);
      expect(controller.byId('b2')!.authors, ['Kasim']);
    });

    test('bilinmeyen anahtar 0 döner', () async {
      expect(await controller.renameAuthor('yok', 'X'), 0);
    });

    test('depo hatasında kalan kitaplar dokunulmaz', () async {
      final errors = <String>[];
      final failingRepo = FakeBookRepository(
        initial: repository.store.toList(),
        failSaveForId: 'b2',
      );
      final failing = LibraryController(
        failingRepo,
        onNotify: (title, message) => errors.add('$title: $message'),
      );
      failing.books.assignAll(failingRepo.store);

      final changed = await failing.renameAuthor('kasim', 'Kasım');

      // b2'nin kaydı hata verir; sonrasındaki b3/b4 güncellenmez.
      expect(changed, 1);
      expect(failing.byId('b1')!.authors, ['Kasım']);
      expect(failing.byId('b2')!.authors, ['Kasim']);
      expect(failing.byId('b3')!.authors, ['Kasim', 'Orhan Pamuk']);
      expect(failing.byId('b4')!.authors, ['Kasım', 'Kasim']);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Kaydedilemedi'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/core/constants/app_constants.dart';
import 'package:kitaplik/data/datasources/book_local_datasource.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/backup_model.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/organize_plan_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/data/services/backup_service.dart';
import 'package:kitaplik/domain/services/organize_criterion.dart';
import 'package:shared_preferences/shared_preferences.dart';

BookModel book(
  String id, {
  String? title,
  String? isbn,
  List<String> authors = const [],
  String shelf = '',
}) =>
    BookModel(
      id: id,
      title: title ?? 'Kitap $id',
      isbn: isbn,
      authors: authors,
      shelf: shelf,
      addedAt: DateTime(2026, 1, 1),
    );

ShelfModel shelf(String id, String name,
        {int bookCapacity = 50, int order = 0}) =>
    ShelfModel(
      id: id,
      name: name,
      // Kitap-sayısı kalibrasyonu korunur: N normal kitap ≈ N × 2,5 cm.
      lengthCm: (bookCapacity * ShelfModel.legacyBookCm).ceil(),
      location: order.isEven ? 'Alt kat' : 'Üst kat',
      order: order,
    );

void main() {
  late SharedPreferences prefs;
  late BookLocalDataSource bookStore;
  late ShelfLocalDataSource shelfStore;
  late BackupService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    bookStore = BookLocalDataSource(prefs);
    shelfStore = ShelfLocalDataSource(prefs);
    service = BackupService(bookStore: bookStore, shelfStore: shelfStore);
  });

  group('buildEnvelope', () {
    test('depodaki kitap ve rafları toplar', () async {
      await bookStore.upsert(book('b1', title: 'Dune'));
      await shelfStore.saveShelves([shelf('s1', 'Roman')]);

      final envelope = service.buildEnvelope();
      expect(envelope.books.map((b) => b.id), ['b1']);
      expect(envelope.shelves.map((s) => s.name), ['Roman']);
      expect(envelope.appVersion, AppInfo.version);
    });
  });

  group('birleştirme (merge)', () {
    test('yeni kitaplar eklenir; ISBN aynı olanlar atlanır', () async {
      await bookStore.upsert(book('b1', isbn: '9780441172719'));
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [
          book('x1', title: 'Dune', isbn: '9780441172719'), // aynı ISBN
          book('x2', title: 'Simyacı', isbn: '9789944886443'),
        ],
        shelves: const [],
      );

      final summary =
          await service.applyImport(envelope, BackupImportMode.merge);

      expect(summary.booksImported, 1);
      expect(summary.booksSkipped, 1);
      final ids = bookStore.getBooks().map((b) => b.id).toList();
      expect(ids.contains('b1'), isTrue);
      expect(ids.contains('x1'), isFalse);
      expect(ids.contains('x2'), isTrue);
    });

    test('ISBN yoksa başlık+yazar Türkçe katlamayla eşleşir', () async {
      await bookStore.upsert(
        book('b1', title: 'Dünya', authors: ['Ahmet Ümit']),
      );
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [
          book('x1', title: 'dunya', authors: ['AHMET ÜMİT']),
        ],
        shelves: const [],
      );

      final summary =
          await service.applyImport(envelope, BackupImportMode.merge);
      expect(summary.booksImported, 0);
      expect(summary.booksSkipped, 1);
      expect(bookStore.getBooks().length, 1);
    });

    test('aynı başlık farklı yazarla eklenir', () async {
      await bookStore.upsert(
        book('b1', title: 'Beyaz Gemi', authors: ['Cengiz Aytmatov']),
      );
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [
          book('x1', title: 'Beyaz Gemi', authors: ['Farklı Yazar']),
        ],
        shelves: const [],
      );

      final summary =
          await service.applyImport(envelope, BackupImportMode.merge);
      expect(summary.booksImported, 1);
      expect(bookStore.getBooks().length, 2);
    });

    test('başlığı boş kitap yalnız ISBN ile eşleşir', () async {
      await bookStore.upsert(book('b1', title: '', isbn: '123'));
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [
          // Başlık boş: başlık+yazar anahtarı üretilemez; ISBN farklı
          // olduğu için EKLENMELİ (başlıksız kayıtlar sessizce atlanmaz).
          book('x1', title: '', isbn: '456'),
        ],
        shelves: const [],
      );

      final summary =
          await service.applyImport(envelope, BackupImportMode.merge);
      expect(summary.booksImported, 1);
    });

    test('adı eşleşen raf korunur (Türkçe büyük/küçük harf)', () async {
      await shelfStore.saveShelves([shelf('s1', 'Roman')]);
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: const [],
        shelves: [shelf('z1', 'ROMAN')],
      );

      final summary =
          await service.applyImport(envelope, BackupImportMode.merge);

      expect(summary.shelvesKept, 1);
      expect(summary.shelvesImported, 0);
      final shelves = shelfStore.getShelves();
      expect(shelves.length, 1);
      expect(shelves.first.name, 'Roman'); // mevcut kanonik ad durur
    });

    test('yeni raf eklenir; kitabın raf alanı kanonik ada eşlenir',
        () async {
      await shelfStore.saveShelves([shelf('s1', 'Roman')]);
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [book('x1', title: 'Çocuk kitabı', shelf: 'roman')],
        shelves: [
          shelf('z1', 'Çocuk'), // yeni raf
        ],
      );

      final summary =
          await service.applyImport(envelope, BackupImportMode.merge);

      expect(summary.shelvesImported, 1);
      final shelves = shelfStore.getShelves().map((s) => s.name).toList();
      expect(shelves, containsAll(['Roman', 'Çocuk']));
      final imported = bookStore.getBooks().single;
      expect(imported.shelf, 'Roman'); // 'roman' → kanonik 'Roman'
    });

    test('raf kimliği çakışırsa yeni kimlik üretilir', () async {
      await shelfStore.saveShelves([shelf('s1', 'Roman')]);
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: const [],
        shelves: [shelf('s1', 'Çocuk')], // aynı kimlik, farklı raf!
      );

      await service.applyImport(envelope, BackupImportMode.merge);

      final shelves = shelfStore.getShelves();
      expect(shelves.length, 2);
      expect(shelves.map((s) => s.id).toSet().length, 2); // kimlikler tekil
    });

    test('kitap kimliği çakışırsa yeni kimlik üretilir', () async {
      await bookStore.upsert(book('b1', title: 'Bende olan'));
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [book('b1', title: 'Eşiminki')], // aynı kimlik, farklı kitap
        shelves: const [],
      );

      await service.applyImport(envelope, BackupImportMode.merge);

      final books = bookStore.getBooks();
      expect(books.length, 2);
      expect(books.map((b) => b.id).toSet().length, 2);
      expect(books.map((b) => b.title).toSet(),
          containsAll(['Bende olan', 'Eşiminki']));
    });

    test('sürüyor olan taşıma planı birleştirmede korunur', () async {
      await shelfStore.savePlan(OrganizePlanModel(
        createdAt: DateTime(2026, 11, 19),
        criterion: OrganizeCriterion.author,
        turs: const [],
      ));
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [book('x1', title: 'Yeni')],
        shelves: const [],
      );

      await service.applyImport(envelope, BackupImportMode.merge);
      expect(shelfStore.getPlan(), isNotNull);
    });

    test('özet sayıları doğru raporlanır', () async {
      await bookStore.upsert(book('b1', title: 'Dune'));
      await shelfStore.saveShelves([shelf('s1', 'Roman')]);
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [
          book('x1', title: 'Dune'), // dup
          book('x2', title: 'Simyacı'),
        ],
        shelves: [
          shelf('s1', 'ROMAN'), // kept
          shelf('z1', 'Çocuk'), // new
        ],
      );

      final summary =
          await service.applyImport(envelope, BackupImportMode.merge);

      expect(summary.mode, BackupImportMode.merge);
      expect(summary.booksImported, 1);
      expect(summary.booksSkipped, 1);
      expect(summary.shelvesImported, 1);
      expect(summary.shelvesKept, 1);
      expect(summary.planCleared, isFalse);
    });
  });

  group('üzerine yaz (replace)', () {
    test('kitaplar ve raflar yedekle değiştirilir', () async {
      await bookStore.upsert(book('b1', title: 'Eski kitap'));
      await shelfStore.saveShelves([shelf('s1', 'Eski raf')]);
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [
          book('w1', title: 'Eşimin kitabı 1'),
          book('w2', title: 'Eşimin kitabı 2'),
        ],
        shelves: [shelf('ws1', 'Eşimin rafı', bookCapacity: 70)],
      );

      final summary =
          await service.applyImport(envelope, BackupImportMode.replace);

      expect(summary.mode, BackupImportMode.replace);
      expect(summary.booksImported, 2);
      final books = bookStore.getBooks();
      expect(books.map((b) => b.id), ['w1', 'w2']);
      final shelves = shelfStore.getShelves();
      expect(shelves.single.name, 'Eşimin rafı');
      expect(shelves.single.lengthCm, 175); // 70 kitap ≈ 175 cm
    });

    test('eski taşıma planı temizlenir', () async {
      await shelfStore.savePlan(OrganizePlanModel(
        createdAt: DateTime(2026, 11, 19),
        criterion: OrganizeCriterion.author,
        turs: const [],
      ));
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: const [],
        shelves: const [],
      );

      final summary =
          await service.applyImport(envelope, BackupImportMode.replace);

      expect(summary.planCleared, isTrue);
      expect(shelfStore.getPlan(), isNull);
    });

    test('kişisel tercihlere dokunulmaz', () async {
      await prefs.setInt(SettingsKeys.themeMode, 2);
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [book('w1', title: 'Yeni')],
        shelves: const [],
      );

      await service.applyImport(envelope, BackupImportMode.replace);

      expect(prefs.getInt(SettingsKeys.themeMode), 2);
    });

    test('boş yedek üzerine yaz veritabanını boşaltır', () async {
      await bookStore.upsert(book('b1', title: 'Eski'));
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: const [],
        shelves: const [],
      );

      await service.applyImport(envelope, BackupImportMode.replace);

      expect(bookStore.getBooks(), isEmpty);
      expect(shelfStore.getShelves(), isEmpty);
    });
  });
}

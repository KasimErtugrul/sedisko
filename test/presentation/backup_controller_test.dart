import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/book_local_datasource.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/backup_model.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/data/services/backup_service.dart';
import 'package:kitaplik/data/services/backup_transfer.dart';
import 'package:kitaplik/presentation/controllers/backup_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSharer extends BackupSharer {
  String? lastPath;
  String? lastSubject;
  int callCount = 0;

  @override
  Future<void> shareFile(String path, String subject) async {
    lastPath = path;
    lastSubject = subject;
    callCount++;
  }
}

class FakePicker extends BackupFilePicker {
  FakePicker(this.content);

  final String? content;

  @override
  Future<BackupPickedFile?> pickJsonFile() async =>
      content == null ? null : BackupPickedFile(name: 'yedek.json', content: content!);
}

class FakeSink extends BackupFileSink {
  String? lastContent;

  @override
  Future<String> write(String content) async {
    lastContent = content;
    return '/sahte/yol/kitapligim_yedek.json';
  }
}

BookModel book(String id, String title) => BookModel(
      id: id,
      title: title,
      addedAt: DateTime(2026, 1, 1),
    );

void main() {
  late SharedPreferences prefs;
  late BookLocalDataSource bookStore;
  late ShelfLocalDataSource shelfStore;
  late BackupService service;
  late FakeSharer sharer;
  late FakeSink sink;
  late Directory tempDir;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    bookStore = BookLocalDataSource(prefs);
    shelfStore = ShelfLocalDataSource(prefs);
    service = BackupService(bookStore: bookStore, shelfStore: shelfStore);
    sharer = FakeSharer();
    sink = FakeSink();
    tempDir = await Directory.systemTemp.createTemp('backup_controller_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
    Get.reset();
  });

  BackupController registerController(FakePicker picker) {
    return Get.put<BackupController>(
      BackupController(
        service: service,
        sharer: sharer,
        filePicker: picker,
        fileSink: sink,
        onNotify: (_, __) {},
      ),
      permanent: true,
    );
  }

  group('dosya adı', () {
    test('tarih ve saatle isimlendirilir', () {
      expect(
        BackupController.fileNameFor(DateTime(2026, 11, 19, 9, 5)),
        'kitapligim_yedek_2026-11-19_0905.json',
      );
      expect(
        BackupController.fileNameFor(DateTime(2026, 3, 2, 23, 41)),
        'kitapligim_yedek_2026-03-02_2341.json',
      );
    });
  });

  group('exportAndShare', () {
    test('yedeği dosya havuzuna yazar ve paylaşır', () async {
      final controller = registerController(FakePicker(null));
      await bookStore.upsert(book('b1', 'Dune'));
      await bookStore.upsert(book('b2', 'Simyacı'));
      await shelfStore.saveShelves([
        const ShelfModel(id: 's1', name: 'Roman', lengthCm: 125, order: 0),
      ]);

      await controller.exportAndShare();

      expect(sharer.callCount, 1);
      expect(sink.lastContent, isNotNull);
      expect(sink.lastContent!, contains(BackupEnvelope.formatTag));
      expect(sink.lastContent!, contains('Simyacı'));
      expect(sharer.lastPath, '/sahte/yol/kitapligim_yedek.json');
      expect(sharer.lastSubject, contains('2 kitap'));
      expect(sharer.lastSubject, contains('1 raf'));
    });

    test('gerçek havuz geçici klasöre dosya yazar', () async {
      // TempFileBackupSink'in gerçek dosya davranışı (düz test: gerçek
      // eşzamansız bölge, dosya G/Ç'si sorunsuz tamamlanır).
      final realSink = TempFileBackupSink(() async => tempDir);
      final path = await realSink.write('deneme içerik');
      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(file.parent.path, tempDir.path);
      expect(file.uri.pathSegments.last,
          startsWith('kitapligim_yedek_'));
      expect(await file.readAsString(), 'deneme içerik');
    });

    test('kitaplık boşsa paylaşım yapılmaz', () async {
      final controller = registerController(FakePicker(null));
      await controller.exportAndShare();
      expect(sharer.callCount, 0);
      expect(sink.lastContent, isNull);
      expect(controller.isBusy.value, isFalse);
    });

    test('işlem sonunda meşgul bayrağı düşer', () async {
      final controller = registerController(FakePicker(null));
      await bookStore.upsert(book('b1', 'Dune'));
      await controller.exportAndShare();
      expect(controller.isBusy.value, isFalse);
    });
  });

  group('pickBackupFile (dosya seçme)', () {
    test('kullanıcı vazgeçerse hiçbir şey değişmez', () async {
      final controller = registerController(FakePicker(null));
      await bookStore.upsert(book('b1', 'Var olan'));
      await controller.pickBackupFile();

      expect(bookStore.getBooks().map((b) => b.id), ['b1']);
      expect(controller.isBusy.value, isFalse);
    });

    test('geçersiz dosya hatayla reddedilir, depo değişmez', () async {
      final controller = registerController(FakePicker('bu bir yedek değil'));
      await bookStore.upsert(book('b1', 'Var olan'));

      await controller.pickBackupFile();

      expect(bookStore.getBooks().map((b) => b.id), ['b1']);
      expect(controller.isBusy.value, isFalse);
    });
  });

  group('applyImport', () {
    test('birleştirme depoya yazar ve özet döner', () async {
      final controller = registerController(FakePicker(null));
      await bookStore.upsert(book('b1', 'Dune'));
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [
          book('b1', 'Dune'), // dup
          book('x1', 'Simyacı'),
        ],
        shelves: const [],
      );

      final summary =
          await controller.applyImport(envelope, BackupImportMode.merge);

      expect(summary, isNotNull);
      expect(summary!.booksImported, 1);
      expect(summary.booksSkipped, 1);
      expect(bookStore.getBooks().map((b) => b.id), contains('x1'));
    });

    test('üzerine yaz depoyu değiştirir', () async {
      final controller = registerController(FakePicker(null));
      await bookStore.upsert(book('b1', 'Eski'));
      final envelope = BackupEnvelope(
        exportedAt: DateTime(2026, 11, 19),
        appVersion: '1.14.0',
        books: [book('w1', 'Eşiminki')],
        shelves: const [],
      );

      final summary =
          await controller.applyImport(envelope, BackupImportMode.replace);

      expect(summary!.mode, BackupImportMode.replace);
      expect(bookStore.getBooks().map((b) => b.id), ['w1']);
    });
  });
}

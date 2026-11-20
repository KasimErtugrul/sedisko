import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/book_local_datasource.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/backup_model.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/data/services/backup_service.dart';
import 'package:kitaplik/data/services/backup_transfer.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/presentation/controllers/backup_controller.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/shelf_organize_controller.dart';
import 'package:kitaplik/presentation/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSharer extends BackupSharer {
  int callCount = 0;
  String? lastPath;
  String? lastSubject;

  @override
  Future<void> shareFile(String path, String subject) async {
    callCount++;
    lastPath = path;
    lastSubject = subject;
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

class StubRepository implements BookRepository {
  StubRepository(this._local);

  final BookLocalDataSource _local;

  @override
  Future<List<BookModel>> getBooks() async => _local.getBooks();

  @override
  Future<void> saveBook(BookModel book) => _local.upsert(book);

  @override
  Future<void> deleteBook(String id) => _local.delete(id);

  @override
  Future<BookModel?> fetchBookByIsbn(String isbn) async => null;
}

BookModel book(String id, String title) => BookModel(
      id: id,
      title: title,
      addedAt: DateTime(2026, 1, 1),
    );

/// Ayarlar sekmesindeki "Yedekleme ve aktarım" bölümünün davranışı.
///
/// Tüm akış sahte paylaşım/seçim/havuz ile yürür; gerçek dosya G/Ç'si
/// widget test bölgesinde tamamlanamayacağı için denetleyiciye enjekte
/// edilir (bkz. [BackupFileSink], [BackupFilePicker]).
void main() {
  late SharedPreferences prefs;
  late BookLocalDataSource bookStore;
  late ShelfLocalDataSource shelfStore;
  late BackupService service;
  late FakeSharer sharer;
  late FakeSink sink;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    bookStore = BookLocalDataSource(prefs);
    shelfStore = ShelfLocalDataSource(prefs);
    service = BackupService(bookStore: bookStore, shelfStore: shelfStore);
    sharer = FakeSharer();
    sink = FakeSink();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    Get.put<BookLocalDataSource>(bookStore, permanent: true);
    Get.put<ShelfLocalDataSource>(shelfStore, permanent: true);
    Get.put<BookRepository>(StubRepository(bookStore), permanent: true);
    Get.put<LibraryController>(
      LibraryController(StubRepository(bookStore), onNotify: (_, __) {}),
      permanent: true,
    );
    Get.put<ShelfOrganizeController>(
      ShelfOrganizeController(shelfStore: shelfStore),
      permanent: true,
    );
    // NOT: BackupController setUp'da kaydedilmez — GetX "Get.put" mevcut
    // kalıcı kaydı değiştirmez; her test KENDİ denetleyicisini
    // pumpSettings'ten önce kaydeder, aksi halde ilk örnek gölge eder.
  });

  tearDown(() {
    Get.reset();
  });

  BackupController registerBackup({FakePicker? picker}) {
    return Get.put<BackupController>(
      BackupController(
        service: service,
        sharer: sharer,
        filePicker: picker ?? FakePicker(null),
        fileSink: sink,
      ),
      permanent: true,
    );
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const GetMaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();
  }

  /// Snackbar'ın otomatik kapanma zamanlayıcısı + kapanış animasyonu
  /// tamamlanır; aksi halde test sonunda "pending timer / active ticker"
  /// hatası çıkar.
  Future<void> letSnackbarFinish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  testWidgets('yedekleme bölümü görünür', (tester) async {
    registerBackup();
    await pumpSettings(tester);

    expect(find.text('Yedekleme ve aktarım'), findsOneWidget);
    expect(find.text('Yedeği paylaş (WhatsApp vb.)'), findsOneWidget);
    expect(find.text('Yedeği geri yükle'), findsOneWidget);
  });

  testWidgets('paylaş düğmesi yedeği havuza yazar ve paylaşır',
      (tester) async {
    await bookStore.upsert(book('b1', 'Dune'));
    await bookStore.upsert(book('b2', 'Simyacı'));
    await shelfStore.saveShelves([
      const ShelfModel(id: 's1', name: 'Roman', lengthCm: 125, order: 0),
    ]);
    registerBackup();
    await pumpSettings(tester);

    await tester.tap(find.text('Yedeği paylaş (WhatsApp vb.)'));
    await tester.pumpAndSettle();

    expect(sharer.callCount, 1);
    expect(sink.lastContent, isNotNull);
    expect(sink.lastContent!, contains('kitapligim-yedek'));
    expect(sink.lastContent!, contains('Simyacı'));
    expect(sharer.lastPath, '/sahte/yol/kitapligim_yedek.json');
    expect(sharer.lastSubject, contains('2 kitap'));
    expect(sharer.lastSubject, contains('1 raf'));
  });

  testWidgets('geri yükle: birleştirme iletişim kutusu uygular',
      (tester) async {
    await bookStore.upsert(book('b1', 'Var olan kitap'));
    // Yedek içeriği: 1 yeni kitap + 1 yeni raf (sahte seçici içeriği).
    final envelope = BackupEnvelope(
      exportedAt: DateTime(2026, 11, 19),
      appVersion: '1.14.0',
      books: [book('w1', 'Eşiminki')],
      shelves: [
        const ShelfModel(
            id: 'ws1', name: 'Eşimin rafı', lengthCm: 175, order: 0),
      ],
    );
    registerBackup(picker: FakePicker(envelope.encode()));
    await pumpSettings(tester);

    await tester.tap(find.text('Yedeği geri yükle'));
    // Dialog açıkken meşgul göstergesi döner (sonsuz animasyon);
    // pumpAndSettle yerine sabit süre pump kullanılır.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Yedeği nasıl geri yükleyelim?'), findsOneWidget);
    expect(find.text('Yedekte 1 kitap ve 1 raf var.'), findsOneWidget);

    // 'Birleştir' başlığı açıklama bölümünde de var; düğmeyi hedefle.
    await tester.tap(find.widgetWithText(FilledButton, 'Birleştir'));
    await tester.pumpAndSettle();

    final controller = Get.find<BackupController>();
    expect(controller.isBusy.value, isFalse);
    // Yeni kitap depoya yazıldı ve bellekteki listeye de sirayet etti.
    final libraryBooks = Get.find<LibraryController>().books;
    expect(libraryBooks.map((b) => b.id), contains('w1'));
    // Yeni raf raf denetleyicisine de sirayet etti.
    final shelves = Get.find<ShelfOrganizeController>().shelves;
    expect(shelves.map((s) => s.name), contains('Eşimin rafı'));
    // Mevcut kitap korunmuş olmalı (birleştirme).
    expect(bookStore.getBooks().map((b) => b.id), contains('b1'));
    await letSnackbarFinish(tester);
  });

  testWidgets('geri yükle: vazgeç hiçbir şeyi değiştirmez', (tester) async {
    await bookStore.upsert(book('b1', 'Var olan kitap'));
    final envelope = BackupEnvelope(
      exportedAt: DateTime(2026, 11, 19),
      appVersion: '1.14.0',
      books: [book('w1', 'Eşiminki')],
      shelves: const [],
    );
    registerBackup(picker: FakePicker(envelope.encode()));
    await pumpSettings(tester);

    await tester.tap(find.text('Yedeği geri yükle'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(bookStore.getBooks().map((b) => b.id), ['b1']);
    expect(find.text('Yedeği nasıl geri yükleyelim?'), findsNothing);
    expect(sink.lastContent, isNull);
  });

  testWidgets('geçersiz dosya hata bildirimi verir', (tester) async {
    registerBackup(picker: FakePicker('bu bir yedek değil'));
    await pumpSettings(tester);

    await tester.tap(find.text('Yedeği geri yükle'));
    await tester.pumpAndSettle();

    expect(find.text('Dosya geçersiz'), findsOneWidget);
    expect(bookStore.getBooks(), isEmpty);
    expect(find.text('Yedeği nasıl geri yükleyelim?'), findsNothing);
    expect(sink.lastContent, isNull);
    await letSnackbarFinish(tester);
  });

  testWidgets('kitaplığı boşken paylaşım yapılmaz', (tester) async {
    registerBackup();
    await pumpSettings(tester);

    await tester.tap(find.text('Yedeği paylaş (WhatsApp vb.)'));
    await tester.pumpAndSettle();

    expect(sharer.callCount, 0);
    expect(sink.lastContent, isNull);
    expect(find.text('Kitaplık boş'), findsOneWidget);
    await letSnackbarFinish(tester);
  });
}

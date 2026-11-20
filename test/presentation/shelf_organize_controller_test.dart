import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/domain/repositories/book_repository.dart';
import 'package:kitaplik/domain/services/organize_criterion.dart';
import 'package:kitaplik/presentation/controllers/library_controller.dart';
import 'package:kitaplik/presentation/controllers/settings_controller.dart';
import 'package:kitaplik/presentation/controllers/shelf_organize_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raf düzeni asistanı denetleyicisi: içe aktarma, hızlı kurulum,
/// önizleme → plan → tur işaretleme → yeniden planla akışı.
class FakeBookRepository implements BookRepository {
  FakeBookRepository({List<BookModel>? initial}) : store = [...?initial];

  final List<BookModel> store;

  @override
  Future<List<BookModel>> getBooks() async => [...store];

  @override
  Future<void> saveBook(BookModel book) async {
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

BookModel book(String id, String shelf, {List<String> authors = const []}) {
  return BookModel(
    id: id,
    title: 'Kitap $id',
    authors: authors,
    shelf: shelf,
    addedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late FakeBookRepository repository;
  late ShelfLocalDataSource shelfStore;
  late ShelfOrganizeController controller;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<SettingsController>(
      SettingsController(prefs: prefs),
      permanent: true,
    );
    repository = FakeBookRepository(initial: [
      // 'Salon' rafında 3 kitap (2'si Ece, 1'i Ahmet); 'Mutfak'ta 1 kitap.
      book('e1', 'Salon', authors: ['Ece Temelkuran']),
      book('e2', 'Salon', authors: ['Ece Temelkuran']),
      book('a1', 'Salon', authors: ['Ahmet Ümit']),
      book('x1', 'Mutfak'),
    ]);
    shelfStore = ShelfLocalDataSource(prefs);
    Get.put<LibraryController>(
      LibraryController(repository, onNotify: (_, __) {}),
      permanent: true,
    );
    await Get.find<LibraryController>().loadBooks();
    Get.put<ShelfOrganizeController>(
      ShelfOrganizeController(shelfStore: shelfStore),
      permanent: true,
    );
    controller = Get.find<ShelfOrganizeController>();
  });

  tearDown(() {
    Get.reset();
  });

  group('raf tanımları', () {
    test('raflar tanımsızken kitaplardaki raf adları içe aktarılır', () async {
      final imported = await controller.importExistingShelvesIfEmpty();
      expect(imported, isTrue);
      expect(controller.shelves.length, 2); // Salon + Mutfak
      expect(controller.shelves
          .every((s) => s.lengthCm == ShelfModel.defaultLengthCm), isTrue);
      // İkinci çağrı no-op.
      expect(await controller.importExistingShelvesIfEmpty(), isFalse);
    });

    test('hızlı kurulum raf sayısını kitap yerlerine göre hesaplar', () async {
      // 4 kitap (4 × 25 mm = 100 mm), raf başına 2 kitap ≈ 5 cm → 2 raf.
      final created = await controller.quickSetup(5);
      expect(created, 2);
      expect(controller.shelves.map((s) => s.name).toList(),
          ['Raf 1', 'Raf 2']);
      expect(controller.shelves[1].order, 1);
    });

    test('aynı ad (aksan duyarsız) reddedilir', () async {
      await controller.quickSetup(5);
      expect(
        await controller.addShelf(name: 'RAF 1', lengthCm: 10),
        isFalse,
      );
      expect(
        await controller.addShelf(name: '  ', lengthCm: 10),
        isFalse,
      );
      expect(
        await controller.addShelf(name: 'Raf 3', lengthCm: 0),
        isFalse,
      );
      expect(await controller.addShelf(name: 'Raf 3', lengthCm: 10), isTrue);
      expect(controller.shelves.length, 3);
    });

    test('raf adı değişince kitaplara sirayet eder', () async {
      await controller.importExistingShelvesIfEmpty();
      final salon = controller.shelves
          .firstWhere((s) => s.name == 'Salon');
      final ok = await controller.updateShelf(
        id: salon.id,
        name: 'Oturma Odası',
        lengthCm: 100,
        location: 'Alt kat',
      );
      expect(ok, isTrue);
      // Kitaplar yeni ada taşınmış.
      expect(
        repository.store.every((b) => b.shelf != 'Salon'),
        isTrue,
      );
      expect(
        repository.store.where((b) => b.shelf == 'Oturma Odası').length,
        3,
      );
      // Uzunluk ve yer güncel.
      final renamed = controller.shelves.firstWhere((s) => s.id == salon.id);
      expect(renamed.lengthCm, 100);
      expect(renamed.location, 'Alt kat');
    });

    test('raflar kalıcıya yazılır ve açılışta geri yüklenir', () async {
      await controller.quickSetup(5);
      expect(shelfStore.getShelves().length, 2);
    });
  });

  group('önizleme ve plan', () {
    /// İki katlı senaryo: Raf 1 alt katta, Raf 2 üst katta → taşımalar
    /// kat değişimi içerir, plan çok turlu olur. Raf başına 2 kitap
    /// ≈ 5 cm.
    Future<void> twoFloorSetup() async {
      await controller.quickSetup(5);
      final raf1 =
          controller.shelves.firstWhere((s) => s.name == 'Raf 1');
      final raf2 =
          controller.shelves.firstWhere((s) => s.name == 'Raf 2');
      await controller.updateShelf(
        id: raf1.id,
        name: 'Raf 1',
        lengthCm: 5,
        location: 'Alt kat',
      );
      await controller.updateShelf(
        id: raf2.id,
        name: 'Raf 2',
        lengthCm: 5,
        location: 'Üst kat',
      );
    }

    test('önizleme hiçbir şey yazmaz', () async {
      await twoFloorSetup();
      controller.buildPreview(OrganizeCriterion.author);
      expect(controller.preview.value, isNotNull);
      // Plan üretilmedi, kitaplar dokunulmaz.
      expect(controller.plan.value, isNull);
      expect(shelfStore.getPlan(), isNull);
    });

    test('plan üretilir, kalıcıya yazılır; konan kitaplar tur işaretiyle güncellenir',
        () async {
      await twoFloorSetup();
      controller.buildPreview(OrganizeCriterion.author);
      await controller.createPlan();

      final plan = controller.plan.value;
      expect(plan, isNotNull);
      expect(shelfStore.getPlan(), isNotNull);
      expect(plan!.turs, isNotEmpty);
      expect(plan.totalMoveCount, greaterThan(0));
      // Kat etiketleri farklı: plan en az iki tur içerir.
      expect(plan.turs.length, greaterThanOrEqualTo(2));

      // 1. tur işaretlenir: yalnız KONAN kitaplar güncellenir; alınıp
      // yolda olanlar dokunulmaz.
      final firstTur = plan.turs.first;
      final droppedInFirst = {
        for (final action in firstTur.actions)
          if (!action.isPickup)
            for (final move in action.moves) move.bookId: move.toShelf,
      };
      final ok = await controller.markTurDone(0);
      expect(ok, isTrue);
      expect(controller.plan.value!.completedCount, 1);
      expect(shelfStore.getPlan()!.completedCount, 1);
      for (final entry in droppedInFirst.entries) {
        final updated =
            repository.store.firstWhere((b) => b.id == entry.key);
        expect(updated.shelf, entry.value);
      }

      // 2. tur: konan kitaplar hedef rafına yazılır.
      final secondTur = controller.plan.value!.turs[1];
      final droppedInSecond = {
        for (final action in secondTur.actions)
          if (!action.isPickup)
            for (final move in action.moves) move.bookId: move.toShelf,
      };
      await controller.markTurDone(1);
      for (final entry in droppedInSecond.entries) {
        final updated =
            repository.store.firstWhere((b) => b.id == entry.key);
        expect(updated.shelf, entry.value);
      }
    });

    test('plan tamamlanınca anahtar silinir', () async {
      await controller.quickSetup(10); // tek raf; hepsi bir rafa toplanır
      // Hepsi zaten tek rafta mı? Salon 3 + Mutfak 1 = 4 kitap,
      // kriter yazara göre: gruplar Raf 1'e sığar; Mutfak'tan taşınma var.
      controller.buildPreview(OrganizeCriterion.author);
      await controller.createPlan();
      expect(controller.plan.value, isNotNull);

      final total = controller.plan.value!.turs.length;
      for (var i = 0; i < total; i++) {
        await controller.markTurDone(i);
      }
      expect(controller.plan.value, isNull);
      expect(shelfStore.getPlan(), isNull);
    });

    test('plan dışı kitaplar (sonradan eklenenler) raporlanır', () async {
      await controller.quickSetup(5);
      controller.buildPreview(OrganizeCriterion.author);
      await controller.createPlan();
      expect(controller.plan.value, isNotNull);

      // Plandan sonra yeni kitap ekle.
      await Get.find<LibraryController>().saveBook(
        book('yeni1', ''),
        deriveLog: false,
      );
      expect(controller.planOutsiders.map((b) => b.id), contains('yeni1'));
    });

    test('yeniden planla kalan işi mevcut durumdan kurar', () async {
      await twoFloorSetup();
      controller.buildPreview(OrganizeCriterion.author);
      await controller.createPlan();
      final firstPlan = controller.plan.value!;
      final totalMoves = firstPlan.totalMoveCount;
      expect(totalMoves, greaterThan(0));

      // İlk turu (alım) tamamla — veri henüz değişmez; ikinci turdaki
      // koymalar kitapları hedefe yazar.
      await controller.markTurDone(0);
      final afterFirst = controller.plan.value;
      expect(afterFirst, isNotNull);
      if (afterFirst!.turs.length > 1) {
        await controller.markTurDone(1);
      }

      // Tamamlanmış koymalar yeni planda artık yok.
      await controller.replan();

      final newPlan = controller.plan.value;
      expect(newPlan, isNotNull);
      expect(newPlan!.completedCount, 0);
      expect(newPlan.totalMoveCount, lessThan(totalMoves));
      // Kriter korunur.
      expect(newPlan.criterion, OrganizeCriterion.author);
    });

    test('plan iptali kitaplara dokunmaz', () async {
      await controller.quickSetup(5);
      controller.buildPreview(OrganizeCriterion.author);
      await controller.createPlan();
      await controller.cancelPlan();
      expect(controller.plan.value, isNull);
      expect(shelfStore.getPlan(), isNull);
      // Kitaplar hâlâ eski raflarında.
      expect(
        repository.store.firstWhere((b) => b.id == 'e1').shelf,
        'Salon',
      );
    });
  });

  group('bozuk kalıcı veri', () {
    test('bilinmeyen kriterli plan açılışta yok sayılır', () async {
      SharedPreferences.setMockInitialValues({
        'organize_plan_v1': '{"criterion":"bilinmeyen","turs":[]}',
      });
      // Yeni prefs ile yeni denetleyici: plan null gelmeli.
      final prefs = await SharedPreferences.getInstance();
      final store2 = ShelfLocalDataSource(prefs);
      expect(store2.getPlan(), isNull);
    });

    test('bozuk JSON plan açılışta yok sayılır', () async {
      SharedPreferences.setMockInitialValues({
        'organize_plan_v1': '{{{{',
      });
      final prefs = await SharedPreferences.getInstance();
      final store2 = ShelfLocalDataSource(prefs);
      expect(store2.getPlan(), isNull);
    });
  });

  group('favoriler (1.15.0; 1.19.0\'da yalnız yazar kriterinde)', () {
    test('favori tercihleri kalıcıya yazılır ve yeni denetleyicide geri yüklenir',
        () async {
      await controller.quickSetup(10);
      final raf1 = controller.shelves.firstWhere((s) => s.name == 'Raf 1');
      await controller.setFavoriteShelf(raf1.id);
      await controller.addFavoriteAuthor('Ece Temelkuran');

      final reloaded = ShelfOrganizeController(shelfStore: shelfStore);
      reloaded.onInit();
      expect(reloaded.favoriteShelfId.value, raf1.id);
      expect(reloaded.favoriteAuthors.toList(), ['Ece Temelkuran']);
    });

    test('boş/yinelenen yazar adları reddedilir (Türkçe katlamayla)', () async {
      expect(await controller.addFavoriteAuthor('   '), isFalse);
      expect(await controller.addFavoriteAuthor('Ece Temelkuran'), isTrue);
      expect(await controller.addFavoriteAuthor('Ece Temelkuran'), isFalse);
      // Aksan/büyük-küçük farkı da yinelen sayılır.
      expect(await controller.addFavoriteAuthor('  ECE TEMELKURAN '),
          isFalse);
      expect(controller.favoriteAuthors.length, 1);
    });

    test('favori yazar silinir', () async {
      await controller.addFavoriteAuthor('Ece Temelkuran');
      await controller.addFavoriteAuthor('Ahmet Ümit');
      await controller.removeFavoriteAuthor('Ece Temelkuran');
      expect(controller.favoriteAuthors.toList(), ['Ahmet Ümit']);
    });

    test('tanımsız raf favori olarak seçilemez; raf silinince tercih geçersizleşir',
        () async {
      await controller.quickSetup(5);
      final raf1 = controller.shelves.firstWhere((s) => s.name == 'Raf 1');
      await controller.setFavoriteShelf('olmayan-id');
      expect(controller.favoriteShelfId.value, isNull);

      await controller.setFavoriteShelf(raf1.id);
      expect(controller.effectiveFavoriteShelf?.id, raf1.id);

      await controller.removeShelf(raf1.id);
      expect(controller.effectiveFavoriteShelf, isNull);
    });

    test('öneriler kitap sayısı çoktan aza dizilir; favoriler listeden çıkar',
        () {
      // Depo: Ece ×2, Ahmet ×1, yazarı yok ×1.
      expect(controller.favoriteAuthorSuggestions(),
          ['Ece Temelkuran', 'Ahmet Ümit']);

      // SetUp'taki raflar yokken de çalışır (yalnız kitaplara bakar).
    });

    test('öneriler favori eklenince güncellenir', () async {
      await controller.addFavoriteAuthor('Ece Temelkuran');
      expect(controller.favoriteAuthorSuggestions(), ['Ahmet Ümit']);
    });

    test('önizleme favori rafı ve yazarları plana uygular', () async {
      await controller.quickSetup(5);
      final raf2 = controller.shelves.firstWhere((s) => s.name == 'Raf 2');
      await controller.setFavoriteShelf(raf2.id);
      await controller.addFavoriteAuthor('Ece Temelkuran');

      controller.buildPreview(OrganizeCriterion.author);

      final arrangement = controller.preview.value!;
      expect(controller.previewOptions.value?.favoriteShelfId, raf2.id);
      // Favori raf (Raf 2) Ece'nin iki kitabıyla başlar.
      expect(arrangement.shelves[1].books.take(2).map((b) => b.id),
          ['e1', 'e2']);
      // Kalan kitaplar (Ahmet + yazarsız) Raf 1'e dağılır.
      expect(arrangement.shelves[0].books.map((b) => b.id),
          containsAll(['a1', 'x1']));
    });

    test('cm modeli toplam yeri hesaplar; metin kitap sayısı + cm yazar',
        () async {
      await controller.quickSetup(50);
      // 4 kitap (bilinmeyen sayfa = 25 mm) + 1 kalın kitap (700 sayfa
      // = 49 mm): toplam 149 mm = 14,9 cm.
      await Get.find<LibraryController>().saveBook(
        BookModel(
          id: 'kalin1',
          title: 'Kalın Kitap',
          pageCount: 700,
          addedAt: DateTime(2026, 1, 1),
        ),
        deriveLog: false,
      );

      expect(controller.totalBookMm, 149);
      expect(controller.totalLengthCm, 50); // tek 50 cm'lik raf
      expect(controller.totalOccupancyText(),
          '5 kitap • 14,9 cm / 50 cm');
    });

    test('raf doluluk metni kitap sayısı + cm verir', () async {
      await controller.quickSetup(50);
      await Get.find<LibraryController>().saveBook(
        BookModel(
          id: 'kalin1',
          title: 'Kalın Kitap',
          pageCount: 700,
          shelf: 'Raf 1',
          addedAt: DateTime(2026, 1, 1),
        ),
        deriveLog: false,
      );

      expect(controller.shelfOccupancyText('Raf 1'),
          '1 kitap • 4,9 cm/50 cm');
    });
  });
}

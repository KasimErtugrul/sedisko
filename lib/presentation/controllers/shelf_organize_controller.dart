import 'package:get/get.dart';

import '../../core/utils/text_normalizer.dart';
import '../../data/datasources/shelf_local_datasource.dart';
import '../../data/models/book_model.dart';
import '../../data/models/organize_plan_model.dart';
import '../../data/models/shelf_model.dart';
import '../../domain/services/move_plan_builder.dart';
import '../../domain/services/organize_criterion.dart';
import '../../domain/services/shelf_planner.dart';
import 'library_controller.dart';

/// Raf düzeni asistanının denetleyicisi.
///
/// Üç iş yapar:
/// 1. **Raf tanımları** (ad + kapasite + yer + sıra): `shelves_v1`'de
///    kalıcı. Kitapların raf ataması hâlâ kitap kaydındadır; raf adı
///    değişirse kitaplara da sirayet eder.
/// 2. **Hedef düzen önizlemesi**: [ShelfPlanner] saf servisiyle üretilir,
///    kullanıcı onaylamadan hiçbir şey yazılmaz.
/// 3. **Taşıma planı**: [MovePlanBuilder] turları üretir, `organize_plan_v1`
///    anahtarında kalıcıdır; her tur "Yaptım" ile işaretlendiğinde o turda
///    KONAN kitapların rafı anında güncellenir (uygulama fiziksel gerçekle
///    aynı kalır). Plan bitince anahtar silinir.
class ShelfOrganizeController extends GetxController {
  ShelfOrganizeController({required ShelfLocalDataSource shelfStore})
      : _shelfStore = shelfStore;

  final ShelfLocalDataSource _shelfStore;

  /// Tanımlı raflar; fiziksel sıraya (order) göre tutulur.
  final shelves = <ShelfModel>[].obs;

  /// Sürüyor olan taşıma planı; yoksa `null`.
  final plan = Rxn<OrganizePlanModel>();

  /// Önizleme (henüz uygulanmamış hedef düzen); sayfa kapatınca temizlenir.
  final preview = Rxn<ShelfArrangement>();
  final previewCriterion = Rxn<OrganizeCriterion>();

  static const int defaultCapacity = 50;
  static const int carryLimit = MovePlanBuilder.defaultCarryLimit;

  LibraryController get _library => Get.find<LibraryController>();

  List<BookModel> get books => _library.books;

  int get bookCount => books.length;

  int get totalCapacity =>
      shelves.fold(0, (sum, shelf) => sum + shelf.capacity);

  /// Kapasite toplamı kitap sayısının altındaysa plan taşan kitapları
  /// Karışık rafına itecektir; kurulum ekranında uyarı olarak gösterilir.
  bool get needsMoreCapacity => bookCount > totalCapacity;

  @override
  void onInit() {
    super.onInit();
    shelves.assignAll(_shelfStore.getShelves());
    plan.value = _shelfStore.getPlan();
  }

  /// Depodan rafları ve planı yeniden okur; yedek içe aktarması depoya
  /// dışarıdan yazdıktan sonra bellek görüntüsünü güncel tutmak için
  /// [BackupController] çağırır.
  void reloadFromStore() {
    shelves.assignAll(_shelfStore.getShelves());
    plan.value = _shelfStore.getPlan();
  }

  // ---------- Raf tanımları ----------

  /// Raflar tanımlanmamışsa kitaplardaki mevcut raf adlarını varsayılan
  /// kapasiteyle içe aktarır; kullanıcı sonra kapasiteleri düzenler.
  /// İçe aktarma yapıldıysa `true` döner.
  Future<bool> importExistingShelvesIfEmpty() async {
    if (shelves.isNotEmpty) return false;
    final names = _library.shelves;
    if (names.isEmpty) return false;

    shelves.assignAll([
      for (var i = 0; i < names.length; i++)
        ShelfModel(
          id: BookModel.newId(),
          name: names[i],
          capacity: defaultCapacity,
          location: '',
          order: i,
        ),
    ]);
    await _persistShelves();
    return true;
  }

  /// Hızlı kurulum: her raf [capacityPerShelf] kitap alacak şekilde
  /// 'Raf 1..N' rafları açılır; N = ceil(kitap sayısı / kapasite).
  /// Mevcut tanımların yerine geçer (UI onay sorar).
  Future<int> quickSetup(int capacityPerShelf) async {
    final capacity = capacityPerShelf < 1 ? 1 : capacityPerShelf;
    final shelfCount = maxOf(1, (bookCount / capacity).ceil());
    shelves.assignAll([
      for (var i = 0; i < shelfCount; i++)
        ShelfModel(
          id: BookModel.newId(),
          name: 'Raf ${i + 1}',
          capacity: capacity,
          location: '',
          order: i,
        ),
    ]);
    await _persistShelves();
    return shelfCount;
  }

  /// Raf adının doğrulaması: boş değil ve (kendi hariç) benzersiz.
  bool isNameUsable(String name, {String? exceptId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    final key = TextNormalizer.searchKey(trimmed);
    return shelves.every((shelf) =>
        shelf.id == exceptId ||
        TextNormalizer.searchKey(shelf.name) != key);
  }

  Future<bool> addShelf({
    required String name,
    required int capacity,
    String location = '',
  }) async {
    if (!isNameUsable(name) || capacity < 1) return false;
    shelves.add(ShelfModel(
      id: BookModel.newId(),
      name: name.trim(),
      capacity: capacity,
      location: location.trim(),
      order: _nextOrder(),
    ));
    await _persistShelves();
    return true;
  }

  /// Rafı günceller. Ad değişimi kitaplara sirayet eder: eski ada bağlı
  /// kitaplar yeni ada taşınır (raf ataması ad bazlıdır).
  Future<bool> updateShelf({
    required String id,
    required String name,
    required int capacity,
    String location = '',
  }) async {
    final index = shelves.indexWhere((shelf) => shelf.id == id);
    if (index < 0) return false;
    if (!isNameUsable(name, exceptId: id) || capacity < 1) return false;

    final old = shelves[index];
    final newName = name.trim();
    shelves[index] = old.copyWith(
      name: newName,
      capacity: capacity,
      location: location.trim(),
    );

    // Ad gerçekten değiştiyse kitaplara sirayet et.
    if (TextNormalizer.searchKey(old.name) !=
        TextNormalizer.searchKey(newName)) {
      for (final book in books.where((b) =>
          TextNormalizer.searchKey(b.shelf.trim()) ==
          TextNormalizer.searchKey(old.name))) {
        await _library.saveBook(
          book.copyWith(shelf: newName),
          deriveLog: false,
        );
      }
    }
    await _persistShelves();
    return true;
  }

  /// Raf tanımını siler; kitapların ataması kalır (ad hâlâ kitaplarda
  /// durur) ama plan artık bu rafı tanımaz. UI yeniden planlamayı önerir.
  Future<void> removeShelf(String id) async {
    shelves.removeWhere((shelf) => shelf.id == id);
    await _persistShelves();
  }

  /// Rafı [delta] kadar yukarı/aşağı kaydırır (fiziksel gezinti sırası).
  Future<void> moveShelf(String id, int delta) async {
    final ordered = [...shelves]
      ..sort((a, b) => a.order.compareTo(b.order));
    final index = ordered.indexWhere((shelf) => shelf.id == id);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= ordered.length) return;

    final reordered = [...ordered];
    final item = reordered.removeAt(index);
    reordered.insert(target, item);
    shelves.assignAll([
      for (var i = 0; i < reordered.length; i++)
        reordered[i].copyWith(order: i),
    ]);
    await _persistShelves();
  }

  int _nextOrder() {
    var maxOrder = -1;
    for (final shelf in shelves) {
      if (shelf.order > maxOrder) maxOrder = shelf.order;
    }
    return maxOrder + 1;
  }

  Future<void> _persistShelves() async {
    try {
      await _shelfStore.saveShelves(shelves.toList());
    } catch (_) {
      Get.snackbar(
        'Kaydedilemedi',
        'Raf tanımları diske yazılamadı.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ---------- Sorgular ----------

  /// [shelfName] rafındaki (kitap kayıtlarındaki) kitap sayısı.
  int shelfCount(String shelfName) => books
      .where((b) => TextNormalizer.searchKey(b.shelf.trim()) ==
          TextNormalizer.searchKey(shelfName.trim()))
      .length;

  /// [shelfName] için tanımlı raf; yoksa `null` (tanımsız raf).
  ShelfModel? shelfByName(String shelfName) {
    final key = TextNormalizer.searchKey(shelfName.trim());
    for (final shelf in shelves) {
      if (TextNormalizer.searchKey(shelf.name) == key) return shelf;
    }
    return null;
  }

  // ---------- Önizleme ve plan ----------

  /// [criterion] için hedef düzeni üretir; HİÇBİR ŞEY yazmaz — kullanıcı
  /// önizleme sayfasında onaylayana kadar bekler.
  void buildPreview(OrganizeCriterion criterion) {
    previewCriterion.value = criterion;
    preview.value = ShelfPlanner.arrange(books, shelves, criterion);
  }

  void clearPreview() {
    preview.value = null;
    previewCriterion.value = null;
  }

  /// Önizlemeden taşıma planı üretir ve kalıcıya yazar. Taşınacak kitap
  /// yoksa plan `null` kalır (UI bilgi gösterir).
  Future<void> createPlan() async {
    final arrangement = preview.value;
    final criterion = previewCriterion.value;
    if (arrangement == null || criterion == null) return;

    final result = MovePlanBuilder.build(
      books: books,
      arrangement: arrangement,
      shelves: [for (final planned in arrangement.shelves) planned.shelf],
      carryLimit: carryLimit,
    );

    if (result.turs.isEmpty) {
      plan.value = null;
      await _shelfStore.savePlan(null);
      preview.value = null;
      return;
    }

    final newPlan = OrganizePlanModel(
      criterion: criterion,
      createdAt: DateTime.now(),
      turs: result.turs,
    );
    plan.value = newPlan;
    await _shelfStore.savePlan(newPlan);
    preview.value = null;
    previewCriterion.value = null;
  }

  /// [index] turunu "Yaptım" olarak işaretler: o turda KONAN kitapların
  /// rafı anında güncellenir (yalnız alınıp yolda olanlar henüz yazılmaz —
  /// yerleştirme kendi turunda yazılır). Tüm turlar bitince plan silinir.
  Future<bool> markTurDone(int index) async {
    final current = plan.value;
    if (current == null) return false;
    if (index < 0 || index >= current.turs.length) return false;
    if (current.completedTurIndexes.contains(index)) return true;

    // Yalnız bu turda KONAN kitaplar yazılır: alınıp yolda olanların
    // rafı, yerleştikleri turun işaretiyle güncellenir (uygulama daima
    // fiziksel gerçekle aynı kalır).
    final dropped = <PlanMove>[];
    for (final action in current.turs[index].actions) {
      if (!action.isPickup) dropped.addAll(action.moves);
    }
    final targets = <String, String>{};
    for (final move in dropped) {
      targets[move.bookId] = move.toShelf;
    }

    for (final entry in targets.entries) {
      final book = _library.byId(entry.key);
      if (book == null) continue; // kitap arada silinmişse atla
      final ok = await _library.saveBook(
        book.copyWith(shelf: entry.value),
        deriveLog: false,
      );
      if (!ok) return false; // depo hatası: ilerleme işaretlenmez
    }

    final updated = current
        .withCompleted([...current.completedTurIndexes, index]);
    if (updated.isComplete) {
      plan.value = null;
      await _shelfStore.savePlan(null);
    } else {
      plan.value = updated;
      await _shelfStore.savePlan(updated);
    }
    return true;
  }

  /// Kalan işi MEVCUT gerçek durumdan yeniden hesaplar (kullanıcı arada
  /// elle oynadıysa ya da yarım kaldıysa). Kriter korunur.
  Future<void> replan() async {
    final criterion = plan.value?.criterion ?? previewCriterion.value;
    if (criterion == null) return;
    plan.value = null;
    preview.value = null;
    preview.value = ShelfPlanner.arrange(books, shelves, criterion);
    previewCriterion.value = criterion;
    await createPlan();
  }

  /// Planı iptal eder; kitapların raf atamaları DOKUNULMAZ.
  Future<void> cancelPlan() async {
    plan.value = null;
    await _shelfStore.savePlan(null);
  }

  /// Plan yapıldıktan sonra eklenen kitaplar; "Yeniden planla" ile
  /// yerleşirler.
  List<BookModel> get planOutsiders {
    final current = plan.value;
    if (current == null) return const <BookModel>[];
    final ids = current.bookIds;
    return books.where((b) => !ids.contains(b.id)).toList();
  }
}

/// Küçük yerel yardımcı: iki int'in büyüğü (dart:math'e bağımlılık
/// istemeyen tek çağrı için).
int maxOf(int a, int b) => a >= b ? a : b;

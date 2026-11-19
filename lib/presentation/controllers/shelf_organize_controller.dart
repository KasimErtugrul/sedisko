import 'package:get/get.dart';

import '../../core/utils/text_normalizer.dart';
import '../../data/datasources/shelf_local_datasource.dart';
import '../../data/models/book_model.dart';
import '../../data/models/organize_plan_model.dart';
import '../../data/models/shelf_model.dart';
import '../../domain/services/book_thickness.dart';
import '../../domain/services/move_plan_builder.dart';
import '../../domain/services/organize_criterion.dart';
import '../../domain/services/organize_options.dart';
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

  /// Önizlemenin üretildiği opsiyonlar (favoriler + kalınlık); önizleme
  /// sayfası favori rozetini ve birim gösterimini buradan bilir.
  final previewOptions = Rxn<OrganizeOptions>();

  /// Favori raf kimliği ('Yok' seçiminde null). Düzen asistanı favori
  /// yazarların kitaplarını bu rafa yerleştirir.
  final favoriteShelfId = Rxn<String>();

  /// Favori yazarlar (kullanıcının sıraladığı liste).
  final favoriteAuthors = <String>[].obs;

  /// Kapasite yer (birim) cinsinden hesaplansın mı? Varsayılan açık:
  /// kalın kitapların sığmadığı gözlemi varsayılan davranışı değiştirdi.
  final thicknessAware = true.obs;

  static const int defaultCapacity = 50;
  static const int carryLimit = MovePlanBuilder.defaultCarryLimit;

  LibraryController get _library => Get.find<LibraryController>();

  List<BookModel> get books => _library.books;

  int get bookCount => books.length;

  int get totalCapacity =>
      shelves.fold(0, (sum, shelf) => sum + shelf.capacity);

  /// Kitapların toplam kapladığı yer (yarım birim): kalınlık hesabı
  /// açıksa sayfa sayısından, kapalıysa her kitaba 1 birim.
  int get totalBookHalfUnits => books.fold(
        0,
        (sum, book) => sum + BookThickness.costHalfUnits(
              book.pageCount,
              thicknessAware: thicknessAware.value,
            ),
      );

  /// Rafların toplam yer bütçesi (yarım birim).
  int get totalCapacityHalfUnits => totalCapacity * 2;

  /// Yer toplamı kitapların toplam yerinin altındaysa plan taşan kitapları
  /// Karışık rafına itecektir; kurulum ekranında uyarı olarak gösterilir.
  bool get needsMoreCapacity =>
      totalBookHalfUnits > totalCapacityHalfUnits;

  /// Taşan yer (yarım birim); taşma yoksa 0.
  int get overflowHalfUnits =>
      needsMoreCapacity ? totalBookHalfUnits - totalCapacityHalfUnits : 0;

  /// Kapasite metni: kalınlık modunda birim cinsinden ('38,5/100 birim'),
  /// kapalıyken kitap sayısı ('38/100').
  String totalOccupancyText() => thicknessAware.value
      ? '${BookThickness.formatHalf(totalBookHalfUnits)} / '
          '${BookThickness.formatHalf(totalCapacityHalfUnits)} birim'
      : '$bookCount/$totalCapacity';

  @override
  void onInit() {
    super.onInit();
    shelves.assignAll(_shelfStore.getShelves());
    plan.value = _shelfStore.getPlan();
    favoriteShelfId.value = _shelfStore.getFavoriteShelfId();
    favoriteAuthors.assignAll(_shelfStore.getFavoriteAuthors());
    thicknessAware.value = _shelfStore.getThicknessAware();
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

  // ---------- Favoriler ve kalınlık (1.15.0) ----------

  /// Favori raf; tanım silinmişse (id raflarda yok) `null` döner —
  /// yarım tercih planı etkilemez.
  ShelfModel? get effectiveFavoriteShelf {
    final id = favoriteShelfId.value;
    if (id == null || id.isEmpty) return null;
    for (final shelf in shelves) {
      if (shelf.id == id) return shelf;
    }
    return null;
  }

  /// Favori rafı seçer/temizler. Raf tanımlı değilse reddedilir.
  Future<void> setFavoriteShelf(String? id) async {
    if (id != null && shelves.every((shelf) => shelf.id != id)) return;
    favoriteShelfId.value = id;
    await _shelfStore.saveFavoriteShelfId(id);
  }

  /// Favori yazar ekler: boş ad reddedilir, yinelenenler (Türkçe katlamayla)
  /// sessizce yok sayılır. Eklendiyse `true` döner.
  Future<bool> addFavoriteAuthor(String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return false;
    final key = TextNormalizer.searchKey(name);
    final exists = favoriteAuthors.any(
      (author) => TextNormalizer.searchKey(author) == key,
    );
    if (exists) return false;
    favoriteAuthors.add(name);
    await _shelfStore.saveFavoriteAuthors(favoriteAuthors.toList());
    return true;
  }

  /// Favori yazarı listeden çıkarır.
  Future<void> removeFavoriteAuthor(String name) async {
    favoriteAuthors.remove(name);
    await _shelfStore.saveFavoriteAuthors(favoriteAuthors.toList());
  }

  /// Kitaplıkta en çok kitabı olan yazarlar; favori önerileri için.
  /// Zaten favori olanlar listede yer almaz.
  List<String> favoriteAuthorSuggestions({int limit = 6}) {
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final book in books) {
      for (final raw in book.authors) {
        final author = raw.trim();
        if (author.isEmpty) continue;
        final key = TextNormalizer.searchKey(author);
        counts[key] = (counts[key] ?? 0) + 1;
        display[key] ??= author;
      }
    }
    final favoriteKeys = {
      for (final author in favoriteAuthors) TextNormalizer.searchKey(author),
    };
    final entries = counts.entries
        .where((entry) => !favoriteKeys.contains(entry.key))
        .toList();
    entries.sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return TextNormalizer.compareTr(display[a.key]!, display[b.key]!);
    });
    return [
      for (final entry in entries.take(limit)) display[entry.key]!,
    ];
  }

  /// Kalınlık hesabını açar/kapatır.
  Future<void> setThicknessAware(bool value) async {
    thicknessAware.value = value;
    await _shelfStore.saveThicknessAware(value);
  }

  // ---------- Sorgular ----------

  /// [shelfName] rafındaki (kitap kayıtlarındaki) kitap sayısı.
  int shelfCount(String shelfName) => books
      .where((b) => TextNormalizer.searchKey(b.shelf.trim()) ==
          TextNormalizer.searchKey(shelfName.trim()))
      .length;

  /// [shelfName] rafındaki kitapların kapladığı yer (yarım birim):
  /// kalınlık hesabı açıksa sayfa sayısından, kapalıysa kitap sayısıdır.
  int shelfHalfUnits(String shelfName) => books
      .where((b) => TextNormalizer.searchKey(b.shelf.trim()) ==
          TextNormalizer.searchKey(shelfName.trim()))
      .fold(
        0,
        (sum, book) => sum + BookThickness.costHalfUnits(
              book.pageCount,
              thicknessAware: thicknessAware.value,
            ),
      );

  /// Raf kartlarındaki canlı doluluk metni: kalınlık modunda birim
  /// ('18/40 birim'), kapalıyken kitap sayısı ('18/40').
  String shelfOccupancyText(String shelfName, int capacity) =>
      thicknessAware.value
          ? '${BookThickness.formatHalf(shelfHalfUnits(shelfName))}/'
              '${BookThickness.formatHalf(capacity * 2)} birim'
          : '${shelfCount(shelfName)}/$capacity';

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
  /// önizleme sayfasında onaylayana kadar bekler. Favoriler ve kalınlık
  /// tercihi kurulumdaki anlık duruma göre uygulanır.
  void buildPreview(OrganizeCriterion criterion) {
    final options = _currentOptions();
    previewCriterion.value = criterion;
    previewOptions.value = options;
    preview.value = ShelfPlanner.arrange(books, shelves, criterion,
        options: options);
  }

  void clearPreview() {
    preview.value = null;
    previewCriterion.value = null;
    previewOptions.value = null;
  }

  /// Kurulumun anlık tercihlerinden planlama opsiyonu üretir.
  OrganizeOptions _currentOptions() => OrganizeOptions(
        favoriteShelfId: effectiveFavoriteShelf?.id,
        favoriteAuthors: favoriteAuthors.toList(),
        thicknessAware: thicknessAware.value,
      );

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
  /// elle oynadıysa ya da yarım kaldıysa). Kriter ve opsiyonlar korunur.
  Future<void> replan() async {
    final criterion = plan.value?.criterion ?? previewCriterion.value;
    if (criterion == null) return;
    plan.value = null;
    preview.value = null;
    final options = _currentOptions();
    preview.value = ShelfPlanner.arrange(books, shelves, criterion,
        options: options);
    previewCriterion.value = criterion;
    previewOptions.value = options;
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

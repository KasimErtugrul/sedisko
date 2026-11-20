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
/// 1. **Raf tanımları** (ad + cm uzunluk + yer + sıra): `shelves_v1`'de
///    kalıcı. Kitapların raf ataması hâlâ kitap kaydındadır; raf adı
///    değişirse kitaplara da sirayet eder. Kapasite 1.19.0'dan beri cm
///    cinsindendir: rafın uzunluğu bütçe, kitabın yeri kalınlıktır
///    (420 sayfa ≈ 3 cm, 130 sayfa ≈ 1 cm).
/// 2. **Hedef düzen önizlemesi**: [ShelfPlanner] saf servisiyle üretilir,
///    kullanıcı onaylamadan hiçbir şey yazılmaz. Favori raf/favori yazar
///    tercihi YALNIZ "Yazara göre" kriterinde devreye girer.
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

  /// Önizlemenin üretildiği opsiyonlar (favoriler); önizleme sayfası
  /// favori rozetini buradan bilir.
  final previewOptions = Rxn<OrganizeOptions>();

  /// Favori raf kimliği ('Yok' seçiminde null). Düzen asistanı favori
  /// yazarların kitaplarını bu rafa YALNIZ "Yazara göre" kriterinde
  /// yerleştirir.
  final favoriteShelfId = Rxn<String>();

  /// Favori yazarlar (kullanıcının sıraladığı liste).
  final favoriteAuthors = <String>[].obs;

  /// Yeni raf için varsayılan cm uzunluk (hızlı kurulum ve raf ekleme
  /// diyaloğunun ön dolu değeri).
  static const int defaultShelfLengthCm = ShelfModel.defaultLengthCm;
  static const int carryLimit = MovePlanBuilder.defaultCarryLimit;

  LibraryController get _library => Get.find<LibraryController>();

  List<BookModel> get books => _library.books;

  int get bookCount => books.length;

  /// Rafların toplam cm uzunluğu.
  int get totalLengthCm =>
      shelves.fold(0, (sum, shelf) => sum + shelf.lengthCm);

  /// Rafların toplam yer bütçesi (milimetre).
  int get totalLengthMm => totalLengthCm * 10;

  /// Kitapların toplam kapladığı yer (milimetre): sayfa sayısından
  /// hesaplanan kalınlık (420 sayfa ≈ 3 cm, 130 sayfa ≈ 1 cm).
  int get totalBookMm => books.fold(
        0,
        (sum, book) => sum + BookThickness.mmOf(book.pageCount),
      );

  /// Yer toplamı kitapların toplam yerinin altındaysa plan taşan kitapları
  /// Karışık rafına itecektir; kurulum ekranında uyarı olarak gösterilir.
  bool get needsMoreCapacity => totalBookMm > totalLengthMm;

  /// Taşan yer (milimetre); taşma yoksa 0.
  int get overflowMm => needsMoreCapacity ? totalBookMm - totalLengthMm : 0;

  /// Doluluk metni: kitap sayısı + cm. ('38 kitap • 96,4/125 cm')
  String totalOccupancyText() =>
      '$bookCount kitap • ${BookThickness.formatMm(totalBookMm)} / '
      '${BookThickness.formatMm(totalLengthMm)}';

  @override
  void onInit() {
    super.onInit();
    shelves.assignAll(_shelfStore.getShelves());
    plan.value = _shelfStore.getPlan();
    favoriteShelfId.value = _shelfStore.getFavoriteShelfId();
    favoriteAuthors.assignAll(_shelfStore.getFavoriteAuthors());
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
  /// uzunlukla içe aktarır; kullanıcı sonra cm'leri düzenler.
  /// İçe aktarma yapıldıysa `true` döner.
  Future<bool> importExistingShelvesIfEmpty() async {
    if (shelves.isNotEmpty) return false;
    final names = _library.shelves;
    if (names.isEmpty) return false;

    // Ad benzersizliği aksan/büyük harf duyarsızdır (1.18.1):
    // 'Kitaplık' ve 'kitaplık' yazımları tek rafa birleşir. Yinelenen
    // tanım; plan hedef adlarını karıştırır, önizlemede aynı ada iki
    // kart ve taşma hesabında çift bütçe üretir.
    final seen = <String>{};
    final unique = <String>[
      for (final name in names)
        if (seen.add(TextNormalizer.searchKey(name))) name,
    ];

    shelves.assignAll([
      for (var i = 0; i < unique.length; i++)
        ShelfModel(
          id: BookModel.newId(),
          name: unique[i],
          lengthCm: ShelfModel.defaultLengthCm,
          location: '',
          order: i,
        ),
    ]);
    await _persistShelves();
    return true;
  }

  /// Hızlı kurulum: her raf [lengthCmPerShelf] cm olacak şekilde
  /// 'Raf 1..N' rafları açılır; N = kitapların toplam kalınlığının raf
  /// uzunluğuna bölümünün üst tamsayısı. Mevcut tanımların yerine geçer
  /// (UI onay sorar).
  Future<int> quickSetup(int lengthCmPerShelf) async {
    final lengthCm = lengthCmPerShelf < 1 ? 1 : lengthCmPerShelf;
    final lengthMm = lengthCm * 10;
    final needed = bookCount == 0 ? 1 : (totalBookMm + lengthMm - 1) ~/ lengthMm;
    final shelfCount = needed < 1 ? 1 : needed;
    shelves.assignAll([
      for (var i = 0; i < shelfCount; i++)
        ShelfModel(
          id: BookModel.newId(),
          name: 'Raf ${i + 1}',
          lengthCm: lengthCm,
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
    required int lengthCm,
    String location = '',
  }) async {
    if (!isNameUsable(name) || lengthCm < 1) return false;
    shelves.add(ShelfModel(
      id: BookModel.newId(),
      name: name.trim(),
      lengthCm: lengthCm,
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
    required int lengthCm,
    String location = '',
  }) async {
    final index = shelves.indexWhere((shelf) => shelf.id == id);
    if (index < 0) return false;
    if (!isNameUsable(name, exceptId: id) || lengthCm < 1) return false;

    final old = shelves[index];
    final newName = name.trim();
    shelves[index] = old.copyWith(
      name: newName,
      lengthCm: lengthCm,
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

  // ---------- Favoriler (1.15.0; 1.19.0'da yalnız yazar kriterinde) ----------

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

  // ---------- Sorgular ----------

  /// [shelfName] rafındaki (kitap kayıtlarındaki) kitap sayısı.
  int shelfCount(String shelfName) => books
      .where((b) => TextNormalizer.searchKey(b.shelf.trim()) ==
          TextNormalizer.searchKey(shelfName.trim()))
      .length;

  /// [shelfName] rafındaki kitapların kapladığı yer (milimetre):
  /// sayfa sayısından hesaplanan kalınlık.
  int shelfMm(String shelfName) => books
      .where((b) => TextNormalizer.searchKey(b.shelf.trim()) ==
          TextNormalizer.searchKey(shelfName.trim()))
      .fold(
        0,
        (sum, book) => sum + BookThickness.mmOf(book.pageCount),
      );

  /// Raf kartlarındaki canlı doluluk metni: kitap sayısı + cm.
  /// ('18 kitap • 46,2/125 cm') Tanımsız rafta yalnız kitap sayısı.
  String shelfOccupancyText(String shelfName) {
    final count = shelfCount(shelfName);
    final definition = shelfByName(shelfName);
    if (definition == null) return '$count kitap';
    return '$count kitap • ${BookThickness.formatMm(shelfMm(shelfName))}/'
        '${BookThickness.formatMm(definition.lengthMm)}';
  }

  /// [shelfName] için tanımlı raf; yoksa `null` (tanımsız raf).
  ShelfModel? shelfByName(String shelfName) {
    final key = TextNormalizer.searchKey(shelfName.trim());
    for (final shelf in shelves) {
      if (TextNormalizer.searchKey(shelf.name) == key) return shelf;
    }
    return null;
  }

  /// Kitapların üzerinde durduğu ama hiçbir raf tanımıyla eşleşmeyen
  /// adlar (Türkçe katlamayla; 'Tv Üzeri' ile 'Tv uzeri' aynı kabul
  /// edilir). Boş liste = kitaplıktaki her raf adının tanımı var.
  ///
  /// Kitabın raf ataması ad bazlıdır ve düzen planı yalnız TANIMLI
  /// rafları kullanır: tanım adları kitaplardaki adlarla birebir aynı
  /// değilse doluluklar 0 görünür ve plan kitapları tanım adlarına
  /// dağıtır — kullanıcı gerçek raflarını tanımada bulamayıp çıktıyı
  /// bozuk sanır (1.19.3 kullanıcı raporu: 'Koridor 1' tanımına karşı
  /// kitaplar 'Koridor Raf 1' adındaydı; yalnız 'Tv uzeri' ≡ 'Tv Üzeri'
  /// katlama eşleştiği için tek kart dolu görünüyordu). Bu liste,
  /// uyarı kartlarının ve ad önerilerinin tek kaynağıdır.
  List<String> unmatchedBookShelfNames() {
    final definedKeys = <String>{
      for (final shelf in shelves) TextNormalizer.searchKey(shelf.name),
    };
    final result = <String>[];
    final seen = <String>{};
    // _library.shelves: kitaplardaki benzersiz raf adları, Türkçe sıralı.
    for (final name in _library.shelves) {
      final key = TextNormalizer.searchKey(name);
      if (definedKeys.contains(key) || !seen.add(key)) continue;
      result.add(name);
    }
    return result;
  }

  // ---------- Önizleme ve plan ----------

  /// [criterion] için hedef düzeni üretir; HİÇBİR ŞEY yazmaz — kullanıcı
  /// önizleme sayfasında onaylayana kadar bekler. Favori tercihi yalnız
  /// "Yazara göre" kriterinde uygulanır.
  void buildPreview(OrganizeCriterion criterion) {
    final options = _currentOptions();
    previewCriterion.value = criterion;
    previewOptions.value = options;
    final arrangement = ShelfPlanner.arrange(
      books,
      shelves,
      criterion,
      options: options,
    );
    _explainFavorites(arrangement.warnings, criterion);
    preview.value = arrangement;
  }

  /// Favori tercihlerinin plana yansımadığı durumları AÇIKÇA uyarıya
  /// yazar (1.18.1). Sessiz devre dışı kalma, kullanıcının plan çıktısını
  /// bozuk sanmasının bilinen kaynaklarından biriydi. Tanılar YALNIZ
  /// "Yazara göre" kriterinde üretilir (1.19.0): öteki kriterlerde
  /// favoriler zaten hiç devrede değildir.
  ///
  /// - Favori raf tercihi kayıtlı ama raf artık yok (raflar hızlı
  ///   kurulumla yeniden açılmışsa kimlikler yenilenir): favori
  ///   yerleştirme hiç çalışmadan geçer ve kullanıcı fark etmez.
  /// - Favori yazar adları kitaplık verisiyle eşleşmez (yazım farkı):
  ///   planlayıcı boş grupları sessizce atlar.
  void _explainFavorites(List<String> warnings, OrganizeCriterion criterion) {
    if (criterion != OrganizeCriterion.author) return;
    if (favoriteAuthors.isEmpty) return;

    final favorite = effectiveFavoriteShelf;
    if (favorite == null) {
      final stored = favoriteShelfId.value;
      if (stored != null && stored.isNotEmpty) {
        warnings.add(
          'Favori raf tercihin kayıtlı ama bu raf raflar listesinde yok '
          '(raflar yeniden oluşturulmuş olabilir). Favori yerleştirme bu '
          'planda devre dışı kaldı; kurulumdan favori rafı yeniden seç.',
        );
      }
      warnings.add(
        'Favori yazarların için favori raf seçilmediği için favori '
        'yerleştirme yapılmadı; kitaplar yalnız seçtiğin kritere göre '
        'dağıtıldı.',
      );
      return;
    }

    final bookAuthorKeys = <String>{
      for (final book in books)
        for (final author in book.authors)
          TextNormalizer.searchKey(author.trim()),
    }..remove('');
    final unmatched = <String>[
      for (final author in favoriteAuthors)
        if (!bookAuthorKeys.contains(TextNormalizer.searchKey(author.trim())))
          author,
    ];
    if (unmatched.isNotEmpty) {
      warnings.add(
        'Şu favori yazarlar kitaplıkta bulunamadı (yazım farkı olabilir): '
        '${unmatched.join(', ')}. Bu yazarlar için favori yerleştirme '
        'yapılmadı.',
      );
    }
  }

  /// Önizlemenin özeti: kaç kitap taşınacak, kaç kitap zaten hedefinde.
  /// Önizleme yoksa null. Önizleme sayfasının üst kartı bunu gösterir;
  /// "yalnız 1 kitap değişecek" çıktısı artık kendi kendini açıklar —
  /// kitaplık çoğunlukla hedef düzendeysen bu DOĞRU sonuctur, hata değil.
  ({int moved, int untouched})? previewMoveSummary() {
    final arrangement = preview.value;
    if (arrangement == null) return null;
    var moved = 0;
    for (final book in books) {
      final target = arrangement.targetShelfOf(book.id);
      if (target == null) continue;
      if (book.shelf.trim() != target.trim()) moved++;
    }
    return (moved: moved, untouched: books.length - moved);
  }

  void clearPreview() {
    preview.value = null;
    previewCriterion.value = null;
    previewOptions.value = null;
  }

  /// Kurulumun anlık favori tercihlerinden planlama opsiyonu üretir.
  /// (Kriter "Yazara göre" değilse planlayıcı favorileri zaten yok sayar.)
  OrganizeOptions _currentOptions() => OrganizeOptions(
        favoriteShelfId: effectiveFavoriteShelf?.id,
        favoriteAuthors: favoriteAuthors.toList(),
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
      // Önizleme SİLİNMEZ (1.18.1): boş plan, arayüzün altında
      // preview.value'yu null'a çekiyordu ve kullanıcı önizleme
      // sayfasında "Önizleme yok. Kuruluma dön." yazısıyla baş başa
      // kalıyordu. Sayfa açık kalır; snackbar nedeni anlatır.
      return;
    }

    final newPlan = OrganizePlanModel(
      criterion: criterion,
      createdAt: DateTime.now(),
      turs: result.turs,
      // Kapsama kümesi: plan üretildiğinde kütüphanedeki HER kitap.
      // Taşınmayanlar da kapsanır — onlar hedef raftalarındadır, "sonra
      // eklenmiş" sayılmazlar (1.19.2 düzeltmesi).
      coveredBookIds: [for (final book in books) book.id],
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
  /// elle oynadıysa ya da yarım kaldıysa). Kriter ve favori tercihleri
  /// kurulumun bugünkü durumuyla alınır.
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

  /// Planın KAPSAMADIĞI kitaplar: plan üretildikten sonra kitaplığa
  /// eklenenler. "Yeniden planla" ile yerleşirler.
  ///
  /// Yeni biçem planlarda kapsama kümesi kayıtlıdır (üretim anındaki
  /// tüm kitaplar); kapsam dışı = gerçekten sonradan eklenenler. 1.19.2
  /// ÖNCESİ eski planlarda küme yoktur: eklenme tarihi plan tarihinden
  /// ileri olanlar dışarıda sayılır — taşınmayan kitaplar artık
  /// yanlışlıkla "sonra eklenmiş" görünmez.
  List<BookModel> get planOutsiders {
    final current = plan.value;
    if (current == null) return const <BookModel>[];
    if (current.hasBookCoverage) {
      final covered = current.coveredBookIds.toSet();
      return books.where((b) => !covered.contains(b.id)).toList();
    }
    // Eski biçem plan: kapsama bilinmiyor; eklenme tarihine göre.
    return books
        .where((b) => b.addedAt.isAfter(current.createdAt))
        .toList();
  }
}

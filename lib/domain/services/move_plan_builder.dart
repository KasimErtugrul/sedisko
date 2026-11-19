import 'package:equatable/equatable.dart';

import '../../core/utils/text_normalizer.dart';
import '../../data/models/book_model.dart';
import '../../data/models/organize_plan_model.dart';
import '../../data/models/shelf_model.dart';
import 'shelf_planner.dart';

/// Taşıma planı sonucu: sıralı turlar + özet.
class MovePlanResult extends Equatable {
  const MovePlanResult({
    required this.turs,
    required this.movedCount,
    required this.untouchedCount,
  });

  final List<MoveTurModel> turs;

  /// Yer değiştirecek kitap sayısı.
  final int movedCount;

  /// Hedefi zaten doğru olan, kımıldamayacak kitap sayısı.
  final int untouchedCount;

  @override
  List<Object?> get props => [turs, movedCount, untouchedCount];
}

/// Hedef düzeni fiziksel bir yürüyüş planına çeviren saf servis.
///
/// Kullanıcının evdeki işi şudur: raflar arasında yürürken tek elde
/// [carryLimit] (varsayılan 10) kitap taşır ve her kitap için in çık
/// yapmak istemez. Bu yüzden plan şöyle kurulur:
///
/// - **Tur = tek yer (kat/oda).** Aynı yer etiketli rafların işleri tek
///   turda toplanır; yer değişimi yalnızca eldeki yığın başka yerde
///   konulacağı zaman olur.
/// - **Raf ziyareti sırası:** yerdeki raflar fiziksel sırayla (order)
///   gezilir; tanımsız raflar sonra, 'Rafsız' en sonda.
/// - **"Önce çıkanları al, sonra gelenleri koy":** bir rafta hem çıkış
///   hem giriş varsa ALMA emri KOYMA emrinden önce yazılır; yoksa rafa
///   koyacak yer açılamaz.
/// - **El sınırı:** raftan alınanlar eklendikten sonra eldeki toplam
///   [carryLimit]'i aşamaz. Sığmayanlar sonraki tura kalır (aynı yer için
///   "devam" turu açılır). Ziyaret anındaki anlık fazlalık, yığının rafta
///   yere bırakılıp yeniden toplanmasıyla çözülür — plan metni bunu
///   zaten emir emir anlatır.
/// - **Kararlılık:** tüm seçimler sayılabilir ve eşitlik kırıcıları
///   etiket alfabetik; aynı girdiden aynı plan çıkar.
abstract final class MovePlanBuilder {
  static const int defaultCarryLimit = 10;

  /// Yer etiketi olmayan rafların ve 'Rafsız' kitapların ortak grubu.
  static const String noLocation = 'Yer belirtilmedi';

  static MovePlanResult build({
    required List<BookModel> books,
    required ShelfArrangement arrangement,
    required List<ShelfModel> shelves,
    int carryLimit = defaultCarryLimit,
  }) {
    assert(carryLimit >= 1, 'Taşıma sınırı en az 1 olmalı');

    // 1) Hareketler: hedefi olan ve hedefi mevcut raftan farklı kitaplar.
    final moves = <PlanMove>[];
    for (final book in books) {
      final target = arrangement.targetShelfOf(book.id);
      if (target == null) continue;
      final from = book.shelf.trim();
      final to = target.trim();
      if (from == to) continue;
      moves.add(PlanMove(
        bookId: book.id,
        title: book.title,
        fromShelf: from,
        toShelf: to,
      ));
    }
    if (moves.isEmpty) {
      return MovePlanResult(
        turs: const [],
        movedCount: 0,
        untouchedCount: books.length,
      );
    }

    // 2) Yer anahtarları: raf adı -> serbest etiket ('' olanlar da dahil).
    String locationOf(String shelfName) {
      if (shelfName.isEmpty) return noLocation;
      final key = TextNormalizer.searchKey(shelfName);
      for (final shelf in shelves) {
        if (TextNormalizer.searchKey(shelf.name) == key) {
          final location = shelf.location.trim();
          return location.isEmpty ? noLocation : location;
        }
      }
      return noLocation;
    }

    final pending = [...moves];
    final carried = <PlanMove>[];
    final turs = <MoveTurModel>[];

    // Aynı yerde geçen ardışık geçişler TEK turda birleşir: kullanıcı
    // aynı kattayken tur bölünmez; tur yalnızca yer değişince kapanır.
    var openLocation = '';
    var openLocationSet = false;
    var openActions = <MoveActionModel>[];

    void closeOpenTur() {
      if (!openLocationSet || openActions.isEmpty) {
        openLocationSet = false;
        openActions = <MoveActionModel>[];
        return;
      }
      turs.add(MoveTurModel(location: openLocation, actions: openActions));
      openLocationSet = false;
      openActions = <MoveActionModel>[];
    }

    // 3) Geçiş geçiş yürüyüş. Güvenlik sayacı: bozuk girdide sonsuz
    //    döngü koruması; normal planda geçiş sayısı buna hiç yaklaşmaz.
    var guard = 0;
    while ((pending.isNotEmpty || carried.isNotEmpty) &&
        guard++ < 4 * moves.length + 16) {
      final location = _nextLocation(pending, carried, locationOf);
      if (!openLocationSet || location != openLocation) closeOpenTur();
      openLocation = location;
      openLocationSet = true;
      final actions = openActions;

      for (final shelfName in _visitOrder(
        location: location,
        pending: pending,
        carried: carried,
        shelves: shelves,
        locationOf: locationOf,
      )) {
        final drops = [
          for (final move in carried)
            if (move.toShelf == shelfName) move,
        ];
        final outs = [
          for (final move in pending)
            if (move.fromShelf == shelfName) move,
        ];
        if (outs.isEmpty && drops.isEmpty) continue;

        // El sınırı: buradaki koymalar inince eldeki yer açılır; kalan
        // yer kadar kitap alınır.
        final space = carryLimit - (carried.length - drops.length);
        final take = space > 0 ? outs.take(space).toList() : <PlanMove>[];

        if (take.isNotEmpty) {
          actions.add(MoveActionModel(
            isPickup: true,
            shelf: shelfName,
            moves: take,
          ));
          for (final move in take) {
            pending.remove(move);
            carried.add(move);
          }
        }
        if (drops.isNotEmpty) {
          actions.add(MoveActionModel(
            isPickup: false,
            shelf: shelfName,
            moves: drops,
          ));
          for (final move in drops) {
            carried.remove(move);
          }
        }
      }

      if (openActions.isEmpty) {
        // Savunmacı: seçilen yerde iş yapılamadı (ör. el dolu ve buraya
        // bir şey konmuyor). Bekleyen ilk hareketi tek başına al.
        final first = pending.first;
        openActions.add(MoveActionModel(
          isPickup: true,
          shelf: first.fromShelf,
          moves: [first],
        ));
        pending.remove(first);
        carried.add(first);
      }
    }
    closeOpenTur();

    return MovePlanResult(
      turs: turs,
      movedCount: moves.length,
      untouchedCount: books.length - moves.length,
    );
  }

  // ---------- Yer seçimi ----------

  /// Sonraki turun yeri: el yığını doluysa yığının çoğunlukla gittiği
  /// yer; boşsa işi (alınacak + konacak) en fazla olan yer. Eşitlikte
  /// etiket alfabetik (kararlılık).
  static String _nextLocation(
    List<PlanMove> pending,
    List<PlanMove> carried,
    String Function(String) locationOf,
  ) {
    final counts = <String, int>{};
    if (carried.isNotEmpty) {
      for (final move in carried) {
        final location = locationOf(move.toShelf);
        counts[location] = (counts[location] ?? 0) + 1;
      }
    } else {
      for (final move in pending) {
        final from = locationOf(move.fromShelf);
        final to = locationOf(move.toShelf);
        counts[from] = (counts[from] ?? 0) + 1;
        counts[to] = (counts[to] ?? 0) + 1;
      }
    }

    String best = '';
    var bestCount = -1;
    for (final entry in counts.entries) {
      final count = entry.value;
      if (count > bestCount ||
          (count == bestCount && TextNormalizer.compareTr(
                entry.key,
                best,
              ) <
              0)) {
        best = entry.key;
        bestCount = count;
      }
    }
    return best;
  }

  /// Bu yerde ziyaret edilecek raflar, fiziksel gezinti sırasıyla:
  /// tanımlı raflar order'a göre, sonra tanımsız adlar alfabetik, en
  /// sonda 'Rafsız'.
  static List<String> _visitOrder({
    required String location,
    required List<PlanMove> pending,
    required List<PlanMove> carried,
    required List<ShelfModel> shelves,
    required String Function(String) locationOf,
  }) {
    final names = <String>{};
    for (final move in pending) {
      // Bu yerdeki kaynak raflar (alım) ve hedef raflar (konma) ziyaret
      // edilir; yalnızca kitap ALAN saf hedef raflar da listede olmalı,
      // aksi halde kitap bir geçiş elde bekler.
      if (locationOf(move.fromShelf) == location) names.add(move.fromShelf);
      if (locationOf(move.toShelf) == location) names.add(move.toShelf);
    }
    for (final move in carried) {
      // Elindeki yığının bu yerdeki hedefleri de ziyaret edilmelidir;
      // yoksa kitap geçiş sonunda elde kalır.
      if (locationOf(move.toShelf) == location) names.add(move.toShelf);
    }

    final orderedShelves = [...shelves]
      ..sort((a, b) => a.order.compareTo(b.order));

    int rank(String name) {
      if (name.isEmpty) return 2; // Rafsız en sonda
      final key = TextNormalizer.searchKey(name);
      final defined = orderedShelves
          .any((shelf) => TextNormalizer.searchKey(shelf.name) == key);
      return defined ? 0 : 1;
    }

    final result = names.toList()
      ..sort((a, b) {
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        if (rank(a) == 0) {
          final orderA = orderedShelves
              .firstWhere((shelf) =>
                  TextNormalizer.searchKey(shelf.name) ==
                  TextNormalizer.searchKey(a))
              .order;
          final orderB = orderedShelves
              .firstWhere((shelf) =>
                  TextNormalizer.searchKey(shelf.name) ==
                  TextNormalizer.searchKey(b))
              .order;
          return orderA.compareTo(orderB);
        }
        return TextNormalizer.compareTr(
          a.isEmpty ? ShelfModel.unassignedName : a,
          b.isEmpty ? ShelfModel.unassignedName : b,
        );
      });
    return result;
  }
}

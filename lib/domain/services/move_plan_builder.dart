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
///
/// **Başarım (1.18.1):** tur döngüsü raf adı başına kuyruk/imişle
/// yürür; yer etiketi her hareket için bir kez hesaplanır (eskiden her
/// turda tüm liste taranıp raf tanımları baştan okunuyordu ve büyük
/// kitaplıkta arayüzü saniyelerce donduruyordu — 3000 kitapta 5 saniyeyi
/// aşan blok, Android'de ANR ile "uygulama kilitlendi" olarak görünür).
/// Çıktı eski algoritmayla birebir aynıdır: eşdeğerlik testleri
/// (`move_plan_builder_equivalence_test.dart`) eski referans
/// uygulamanın planıyla karşılaştırılır.
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

    // 2) Yer etiketleri bir kez hesaplanır: raf adı -> serbest etiket
    //    ('' olanlar da dahil). Eski kod her turda her hareket için raf
    //    tanımlarını baştan tarıyordu; büyük kitaplıkta bu kuadratik
    //    maliyet arayüzü donduruyordu. Önbellek, ilk eşleşen rafın yer
    //    etiketini sabitler (aynı ada sahip iki tanımda ilki kazanır —
    //    eski davranışın aynısı).
    final locationCache = <String, String>{};
    String locationOf(String shelfName) {
      return locationCache.putIfAbsent(shelfName, () {
        if (shelfName.isEmpty) return noLocation;
        final key = TextNormalizer.searchKey(shelfName);
        for (final shelf in shelves) {
          if (TextNormalizer.searchKey(shelf.name) == key) {
            final location = shelf.location.trim();
            return location.isEmpty ? noLocation : location;
          }
        }
        return noLocation;
      });
    }

    // Ziyaret sıralaması için raf sıralaması bir kez hesaplanır: arama
    // anahtarı -> (tanımlı mı, order). Aynı adlı iki tanımda ilk eşleşen
    // kazanır — eski firstWhere davranışının aynısı.
    final shelfRankByKey = <String, int>{};
    final shelfOrderByKey = <String, int>{};
    for (final shelf in [...shelves]
      ..sort((a, b) => a.order.compareTo(b.order))) {
      final key = TextNormalizer.searchKey(shelf.name);
      shelfRankByKey.putIfAbsent(key, () => 0);
      shelfOrderByKey.putIfAbsent(key, () => shelf.order);
    }
    int rankOf(String name) {
      if (name.isEmpty) return 2; // Rafsız en sonda
      return shelfRankByKey.containsKey(TextNormalizer.searchKey(name))
          ? 0
          : 1;
    }
    int orderOf(String name) {
      final order = shelfOrderByKey[TextNormalizer.searchKey(name)];
      if (order != null) return order;
      // Tanımsız ad: original listede ilk görülen sıradadır; sıralama
      // kararlılığını korumak için 0 döner (yalnız rank 1 dallarında
      // karşılaştırma order'ı kullanmaz).
      return 0;
    }

    // 3) Hareketler imleşli kuyruklarda: raf adına göre ALMA kuyrukları
    //    (küresel sırayla) ve alınanların KOYMA kuyruğu. İmişler
    //    kimlikle çalışır; eşit görünan iki hareket (aynı kitabın iki
    //    bozuk kaydı) birbirine karışmaz.
    final refs = [for (final move in moves) _MoveRef(move)];
    final pendingByFrom = <String, List<_MoveRef>>{};
    final pendingToCount = <String, int>{};
    for (final ref in refs) {
      pendingByFrom
          .putIfAbsent(ref.move.fromShelf, () => <_MoveRef>[])
          .add(ref);
      pendingToCount[ref.move.toShelf] =
          (pendingToCount[ref.move.toShelf] ?? 0) + 1;
    }
    final queueHeads = <String, int>{
      for (final entry in pendingByFrom.entries) entry.key: 0,
    };

    final carriedRefs = <_MoveRef>[];
    var carriedCount = 0;
    var pendingCount = refs.length;

    void takeRef(_MoveRef ref) {
      ref.taken = true;
      pendingCount--;
      pendingToCount[ref.move.toShelf] =
          (pendingToCount[ref.move.toShelf] ?? 0) - 1;
      carriedRefs.add(ref);
      carriedCount++;
    }

    void dropRef(_MoveRef ref) {
      ref.dropped = true;
      carriedCount--;
    }

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

    // 4) Geçiş geçiş yürüyüş. Güvenlik sayacı: bozuk girdide sonsuz
    //    döngü koruması; normal planda geçiş sayısı buna hiç yaklaşmaz.
    var guard = 0;
    while ((pendingCount > 0 || carriedCount > 0) &&
        guard++ < 4 * moves.length + 16) {
      final location = _nextLocation(refs, carriedCount, locationOf);
      if (!openLocationSet || location != openLocation) closeOpenTur();
      openLocation = location;
      openLocationSet = true;
      final actions = openActions;

      for (final shelfName in _visitOrder(
        location: location,
        refs: refs,
        pendingCount: pendingCount,
        carriedRefs: carriedRefs,
        carriedCount: carriedCount,
        locationOf: locationOf,
        rankOf: rankOf,
        orderOf: orderOf,
      )) {
        // Konacaklar bu ziyaret anında elde yığından okunur: aynı geçişte
        // başka raftan az önce alınanlar da dahil (eski davranışın aynısı).
        // El yığını taşıma sınırıyla (10) sınırlıdır; tarama ucuzdur.
        final drops = <PlanMove>[];
        if (carriedCount > 0) {
          for (final ref in carriedRefs) {
            if (ref.dropped) continue;
            if (ref.move.toShelf == shelfName) drops.add(ref.move);
          }
        }

        // Bu raftan alınacaklar: kuyruğun başından, küresel sırayla.
        final queue = pendingByFrom[shelfName];
        var head = queueHeads[shelfName] ?? 0;
        while (head < (queue?.length ?? 0) && queue![head].taken) {
          head++;
        }
        queueHeads[shelfName] = head;
        final hasOuts = queue != null && head < queue.length;
        if (!hasOuts && drops.isEmpty) continue;

        // El sınırı: buradaki koymalar inince eldeki yer açılır; kalan
        // yer kadar kitap alınır.
        final space = carryLimit - (carriedCount - drops.length);
        var take = const <_MoveRef>[];
        if (space > 0 && hasOuts) {
          final room = space < queue!.length - head
              ? space
              : queue.length - head;
          take = queue.sublist(head, head + room);
          head += room;
          queueHeads[shelfName] = head;
        }

        if (take.isNotEmpty) {
          actions.add(MoveActionModel(
            isPickup: true,
            shelf: shelfName,
            moves: [for (final ref in take) ref.move],
          ));
          for (final ref in take) {
            takeRef(ref);
          }
        }
        if (drops.isNotEmpty) {
          actions.add(MoveActionModel(
            isPickup: false,
            shelf: shelfName,
            moves: drops,
          ));
          // İmişli düşme: yalnız bu rafa konanlar işaretlenir. Eski
          // listeden-çıkarmanın eşdeğeri, küresel elde-sırası korunur.
          for (final move in drops) {
            for (final ref in carriedRefs) {
              if (!ref.dropped && identical(ref.move, move)) {
                dropRef(ref);
                break;
              }
            }
          }
        }
      }

      if (openActions.isEmpty) {
        // Savunmacı: seçilen yerde iş yapılamadı (ör. el dolu ve buraya
        // bir şey konmuyor). Bekleyen ilk hareketi tek başına al.
        _MoveRef? first;
        for (final ref in refs) {
          if (!ref.taken) {
            first = ref;
            break;
          }
        }
        if (first == null) {
          break; // bekleyen kalmadı; elde kalanlar sonraki turda konur
        }
        openActions.add(MoveActionModel(
          isPickup: true,
          shelf: first.move.fromShelf,
          moves: [first.move],
        ));
        takeRef(first);
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
    List<_MoveRef> refs,
    int carriedCount,
    String Function(String) locationOf,
  ) {
    final counts = <String, int>{};
    if (carriedCount > 0) {
      for (final ref in refs) {
        if (!ref.taken || ref.dropped) continue;
        final location = locationOf(ref.move.toShelf);
        counts[location] = (counts[location] ?? 0) + 1;
      }
    } else {
      for (final ref in refs) {
        if (ref.taken) continue;
        final from = locationOf(ref.move.fromShelf);
        final to = locationOf(ref.move.toShelf);
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
    required List<_MoveRef> refs,
    required int pendingCount,
    required List<_MoveRef> carriedRefs,
    required int carriedCount,
    required String Function(String) locationOf,
    required int Function(String) rankOf,
    required int Function(String) orderOf,
  }) {
    final names = <String>{};
    if (pendingCount > 0) {
      for (final ref in refs) {
        if (ref.taken) continue;
        // Bu yerdeki kaynak raflar (alım) ve hedef raflar (konma)
        // ziyaret edilir; yalnızca kitap ALAN saf hedef raflar da
        // listede olmalı, aksi halde kitap bir geçiş elde bekler.
        if (locationOf(ref.move.fromShelf) == location) {
          names.add(ref.move.fromShelf);
        }
        if (locationOf(ref.move.toShelf) == location) {
          names.add(ref.move.toShelf);
        }
      }
    }
    if (carriedCount > 0) {
      for (final ref in carriedRefs) {
        if (ref.dropped) continue;
        // Elindeki yığının bu yerdeki hedefleri de ziyaret edilmelidir;
        // yoksa kitap geçiş sonunda elde kalır.
        if (locationOf(ref.move.toShelf) == location) {
          names.add(ref.move.toShelf);
        }
      }
    }

    final result = names.toList()
      ..sort((a, b) {
        final byRank = rankOf(a).compareTo(rankOf(b));
        if (byRank != 0) return byRank;
        if (rankOf(a) == 0) {
          return orderOf(a).compareTo(orderOf(b));
        }
        return TextNormalizer.compareTr(
          a.isEmpty ? ShelfModel.unassignedName : a,
          b.isEmpty ? ShelfModel.unassignedName : b,
        );
      });
    return result;
  }
}

/// İmişli hareket kaydı: plan hareketi + ALINDI/KONDU işaretleri.
/// Kimlik eşitliği, aynı veriyle üretilmiş iki eşit hareketin
/// birbirine karışmasını da önler.
class _MoveRef {
  _MoveRef(this.move);

  final PlanMove move;
  bool taken = false;
  bool dropped = false;
}

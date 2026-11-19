import 'package:equatable/equatable.dart';

import '../../domain/services/organize_criterion.dart';

/// Taşıma planındaki tek kitap hareketi: [fromShelf] rafından alınır,
/// [toShelf] rafına konur. Boş raf adı 'Rafsız' demektir.
class PlanMove extends Equatable {
  const PlanMove({
    required this.bookId,
    required this.title,
    required this.fromShelf,
    required this.toShelf,
  });

  final String bookId;
  final String title;
  final String fromShelf;
  final String toShelf;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bookId': bookId,
        'title': title,
        'fromShelf': fromShelf,
        'toShelf': toShelf,
      };

  /// Bozuk kayıt `null` döner: kitap kimliği olmayan hareket anlamsızdır.
  static PlanMove? tryFromJson(Map<String, dynamic> json) {
    final bookId = json['bookId'];
    if (bookId is! String || bookId.isEmpty) return null;
    String text(Object? value) => value is String ? value : '';
    return PlanMove(
      bookId: bookId,
      title: text(json['title']),
      fromShelf: text(json['fromShelf']),
      toShelf: text(json['toShelf']),
    );
  }

  @override
  List<Object?> get props => [bookId, title, fromShelf, toShelf];
}

/// Tur içindeki tek fiziksel emir: "X rafından şu kitapları al" ya da
/// "X rafına şu kitapları koy".
class MoveActionModel extends Equatable {
  const MoveActionModel({
    required this.isPickup,
    required this.shelf,
    required this.moves,
  });

  /// true: raftan AL (pickup); false: rafa KOY (drop).
  final bool isPickup;
  final String shelf;
  final List<PlanMove> moves;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': isPickup ? 'al' : 'koy',
        'shelf': shelf,
        'moves': [for (final move in moves) move.toJson()],
      };

  static MoveActionModel? tryFromJson(Map<String, dynamic> json) {
    final shelf = json['shelf'];
    if (shelf is! String) return null;
    final rawMoves = json['moves'];
    if (rawMoves is! List) return null;
    final moves = <PlanMove>[];
    for (final item in rawMoves) {
      if (item is! Map) continue;
      final move =
          PlanMove.tryFromJson(Map<String, dynamic>.from(item));
      if (move != null) moves.add(move);
    }
    if (moves.isEmpty) return null;
    return MoveActionModel(
      isPickup: json['kind'] == 'al',
      shelf: shelf,
      moves: moves,
    );
  }

  @override
  List<Object?> get props => [isPickup, shelf, moves];
}

/// Bir "tur": aynı yerde (kat/oda) yapılan işin tamamı. Kullanıcı turu
/// "Yaptım" diye işaretlediğinde turdaki tüm kitapların rafı güncellenir.
class MoveTurModel extends Equatable {
  const MoveTurModel({required this.location, required this.actions});

  final String location;
  final List<MoveActionModel> actions;

  /// Turdaki tüm kitap hareketleri (uygulama için tek listede).
  List<PlanMove> get moves =>
      [for (final action in actions) ...action.moves];

  /// Turda kaç kitap fiziksel olarak taşınıyor.
  int get moveCount => moves.length;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'location': location,
        'actions': [for (final action in actions) action.toJson()],
      };

  static MoveTurModel? tryFromJson(Map<String, dynamic> json) {
    final location = json['location'];
    if (location is! String) return null;
    final rawActions = json['actions'];
    if (rawActions is! List) return null;
    final actions = <MoveActionModel>[];
    for (final item in rawActions) {
      if (item is! Map) continue;
      final action =
          MoveActionModel.tryFromJson(Map<String, dynamic>.from(item));
      if (action != null) actions.add(action);
    }
    if (actions.isEmpty) return null;
    return MoveTurModel(location: location, actions: actions);
  }

  @override
  List<Object?> get props => [location, actions];
}

/// Kalıcı taşıma planı: kriter + turlar + tamamlanan tur indeksleri.
/// `organize_plan_v1` anahtarında saklanır; tüm turlar tamamlanınca
/// anahtar silinir.
class OrganizePlanModel extends Equatable {
  const OrganizePlanModel({
    required this.criterion,
    required this.createdAt,
    required this.turs,
    this.completedTurIndexes = const [],
  });

  final OrganizeCriterion criterion;
  final DateTime createdAt;
  final List<MoveTurModel> turs;

  /// Tamamlanan turların indeksleri; artan sırada tutulur.
  final List<int> completedTurIndexes;

  int get completedCount => completedTurIndexes.length;

  bool get isComplete =>
      turs.isNotEmpty && completedTurIndexes.length >= turs.length;

  /// Plandaki tüm kitap hareketleri (yeni gelen kitapları ayırmak için).
  Set<String> get bookIds => {
        for (final tur in turs)
          for (final move in tur.moves) move.bookId,
      };

  /// Toplam taşınacak kitap sayısı (benzersiz kitap; aynı kitap alım ve
  /// koyma emirlerinde iki kez görünür).
  int get totalMoveCount => bookIds.length;

  OrganizePlanModel withCompleted(List<int> indexes) =>
      OrganizePlanModel(
        criterion: criterion,
        createdAt: createdAt,
        turs: turs,
        completedTurIndexes: [...indexes]..sort(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'criterion': criterion.name,
        'createdAt': createdAt.toIso8601String(),
        'turs': [for (final tur in turs) tur.toJson()],
        'completed': completedTurIndexes,
      };

  /// Bozuk planda `null` döner; kriter bilinmiyorsa plan geçersizdir.
  static OrganizePlanModel? tryFromJson(Map<String, dynamic> json) {
    OrganizeCriterion? criterion;
    for (final candidate in OrganizeCriterion.values) {
      if (candidate.name == json['criterion']) criterion = candidate;
    }
    if (criterion == null) return null;

    final createdAtRaw = json['createdAt'];
    final createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
        : DateTime.now();

    final rawTurs = json['turs'];
    if (rawTurs is! List) return null;
    final turs = <MoveTurModel>[];
    for (final item in rawTurs) {
      if (item is! Map) continue;
      final tur =
          MoveTurModel.tryFromJson(Map<String, dynamic>.from(item));
      if (tur != null) turs.add(tur);
    }

    final rawCompleted = json['completed'];
    final completed = rawCompleted is List
        ? rawCompleted.whereType<num>().map((e) => e.toInt()).toList()
        : <int>[];

    return OrganizePlanModel(
      criterion: criterion,
      createdAt: createdAt,
      turs: turs,
      completedTurIndexes: completed,
    );
  }

  @override
  List<Object?> get props =>
      [criterion, createdAt, turs, completedTurIndexes];
}

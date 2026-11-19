import 'package:equatable/equatable.dart';

/// Fiziksel rafın uygulamadaki tanımı.
///
/// Kitapların raf ataması `books_v1` içindeki `shelf` (ad) alanında
/// yaşamaya devam eder; bu model yalnızca rafın kendisini tanımlar:
/// kapasitesi (kitap sayısı), serbest yer etiketi ('Alt kat', 'Üst kat',
/// 'Salon'…) ve fiziksel diziliş sırası. Eski veride raf tanımı yoktur;
/// alanlar varsayılanla gelir.
class ShelfModel extends Equatable {
  const ShelfModel({
    required this.id,
    required this.name,
    required this.capacity,
    this.location = '',
    required this.order,
  });

  /// "Karışık kitaplar" rafının sabit adı: sığmayan grup artıkları bu
  /// rafta toplanır. Kullanıcı aynı adla gerçek raf tanımlarsa o raf
  /// kullanılır, tanımlamazsa plan sentetik bir raf üretir.
  static const String mixShelfName = 'Karışık kitaplar';

  /// Rafsız kitaplar için görünen ad ('' atamasın kullanıcı karşılığı).
  static const String unassignedName = 'Rafsız';

  final String id;
  final String name;

  /// Rafın alabileceği kitap sayısı; taşma kuralının temeli.
  final int capacity;

  /// Serbest yer etiketi; boşsa "yer belirtilmedi" grubuna girer.
  final String location;

  /// Kullanıcının belirlediği fiziksel sıra; tur planı rafları bu sırayla
  /// gezer.
  final int order;

  ShelfModel copyWith({
    String? name,
    int? capacity,
    String? location,
    int? order,
  }) {
    return ShelfModel(
      id: id,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      location: location ?? this.location,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'capacity': capacity,
        'location': location,
        'order': order,
      };

  /// Bozuk kayıtta `null` döner; tek bozuk raf tüm listeyi düşürmez.
  static ShelfModel? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;

    final capacity = json['capacity'];
    final location = json['location'];
    final order = json['order'];
    return ShelfModel(
      id: id,
      name: name.trim(),
      // Kapasite 1'in altındaysa 1'e çeken savunmacı düzeltme.
      capacity: capacity is num && capacity >= 1
          ? capacity.toInt()
          : 1,
      location: location is String ? location.trim() : '',
      order: order is num ? order.toInt() : 0,
    );
  }

  @override
  List<Object?> get props => [id, name, capacity, location, order];
}

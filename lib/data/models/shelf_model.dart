import 'package:equatable/equatable.dart';

/// Fiziksel rafın uygulamadaki tanımı.
///
/// **1.19.0 — cm modeli:** rafın kapasitesi artık KULLANICININ cm
/// cinsinden girdiği uzunluktur ([lengthCm]); kitapların yer kapladığı
/// alan sayfa sayısından hesaplanan kalınlıktır (BookThickness: 420
/// sayfa ≈ 3 cm, 130 sayfa ≈ 1 cm). Eski "kaç kitap alır" ([capacity])
/// alanı veri uyumluluğu için yine de yazılır: eski kayıtlı raflar
/// `kapasite × 2,5 cm` ile otomatik cm'ye çevrilir ve eski yedek
/// dosyaları da aynen okunur.
///
/// Kitapların raf ataması `books_v1` içindeki `shelf` (ad) alanında
/// yaşamaya devam eder; bu model yalnızca rafın kendisini tanımlar:
/// uzunluğu, serbest yer etiketi ('Alt kat', 'Üst kat', 'Salon'…) ve
/// fiziksel diziliş sırası.
class ShelfModel extends Equatable {
  const ShelfModel({
    required this.id,
    required this.name,
    required this.lengthCm,
    this.location = '',
    required this.order,
  });

  /// "Karışık kitaplar" rafının sabit adı: sığmayan grup artıkları bu
  /// rafta toplanır. Kullanıcı aynı adla gerçek raf tanımlarsa o raf
  /// kullanılır, tanımlamazsa plan sentetik bir raf üretir.
  static const String mixShelfName = 'Karışık kitaplar';

  /// Rafsız kitaplar için görünen ad ('' atamasın kullanıcı karşılığı).
  static const String unassignedName = 'Rafsız';

  /// Yeni raf için varsayılan uzunluk.
  static const int defaultLengthCm = 100;

  /// Eski verideki kitap-kapasitesinin cm karşılığı: 1 normal kitap
  /// ≈ 2,5 cm (BookThickness ölçeğiyle uyumlu: ≈350 sayfa).
  static const double legacyBookCm = 2.5;

  final String id;
  final String name;

  /// Rafın kitapların dizildiği boş uzunluğu, santimetre (≥ 1).
  final int lengthCm;

  /// Serbest yer etiketi; boşsa "yer belirtilmedi" grubuna girer.
  final String location;

  /// Kullanıcının belirlediği fiziksel sıra; tur planı rafları bu sırayla
  /// gezer.
  final int order;

  /// Rafın yer bütçesi, milimetre (planlamanın iç birimi).
  int get lengthMm => lengthCm * 10;

  /// Eski "kaç kitap alır" karşılığı; yalnız gösterim ve veri uyumluluğu
  /// içindir, planlama bunu kullanmaz.
  int get booksCapacity => (lengthCm / legacyBookCm).round();

  ShelfModel copyWith({
    String? name,
    int? lengthCm,
    String? location,
    int? order,
  }) {
    return ShelfModel(
      id: id,
      name: name ?? this.name,
      lengthCm: lengthCm ?? this.lengthCm,
      location: location ?? this.location,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'lengthCm': lengthCm,
        // Eski alan korunur: yedek dosyaları eski sürümde de açılsın.
        'capacity': booksCapacity,
        'location': location,
        'order': order,
      };

  /// Bozuk kayıtta `null` döner; tek bozuk raf tüm listeyi düşürmez.
  ///
  /// Uzunluk okuma sırası: `lengthCm` varsa o; yoksa eski `capacity ×
  /// 2,5 cm`; o da yoksa varsayılan uzunluk. Böylece 1.18 ve öncesi
  /// verisi (yalnız capacity'li) kayıpsız taşınır.
  static ShelfModel? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;

    final lengthRaw = json['lengthCm'];
    final capacityRaw = json['capacity'];
    final location = json['location'];
    final order = json['order'];

    var lengthCm = 0;
    if (lengthRaw is num && lengthRaw >= 1) {
      lengthCm = lengthRaw.toInt();
    } else if (capacityRaw is num && capacityRaw >= 1) {
      lengthCm = (capacityRaw * legacyBookCm).round();
    }
    // Savunmacı düzeltme: hiçbir uzunluk okunamadıysa varsayılan.
    if (lengthCm < 1) lengthCm = defaultLengthCm;

    return ShelfModel(
      id: id,
      name: name.trim(),
      lengthCm: lengthCm,
      location: location is String ? location.trim() : '',
      order: order is num ? order.toInt() : 0,
    );
  }

  @override
  List<Object?> get props => [id, name, lengthCm, location, order];
}

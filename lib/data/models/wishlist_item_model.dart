/// Satın alınacaklar listesi kaydı.
///
/// 1.18.0: Open Library aramasından veya elle eklenen, kitaplığa henüz
/// girmemiş kitaplar `wishlist_v1` anahtarında JSON liste olarak tutulur.
/// Kayıt kaynak bilgisi taşır (`openlibrary` / `manual`) ve tek dokunuşla
/// doldurulmuş kitap formuna ([WishlistItemModel.toBook]) dönüştürülebilir.
library;

import 'package:equatable/equatable.dart';

import 'book_model.dart';

/// Kaynağın nereden eklendiğini belirtir; kartta rozet olarak gösterilir.
enum WishlistSource {
  openlibrary('openlibrary'),
  manual('manual');

  const WishlistSource(this.key);

  final String key;

  /// Depolamadaki anahtar string'inden okur; bilinmeyen/eksik değerler
  /// elle ekleme olarak yorumlanır.
  static WishlistSource fromKey(String? key) =>
      key == 'openlibrary' ? WishlistSource.openlibrary : WishlistSource.manual;

  // Keşke 5 (1.25.0): rozet de kullanıcının dilini konuşur — 'Manuel'
  // jargondu; "Kendim ekledim" herkes için açık. Depodaki anahtar
  // ('openlibrary' / öteki) DEĞİŞMEZ; yalnız ekrandaki etiket günlük.
  String get label =>
      this == WishlistSource.openlibrary ? 'Open Library' : 'Kendim ekledim';
}

/// copyWith'te "hiç verilmedi" ile "null verildi"yi ayırt eden koruyucu.
const Object _unset = Object();

class WishlistItemModel extends Equatable {
  const WishlistItemModel({
    required this.id,
    required this.title,
    this.authors = const [],
    this.isbn,
    this.publisher,
    this.pageCount = 0,
    this.coverUrl,
    this.note,
    required this.addedAt,
    this.source = WishlistSource.manual,
  });

  final String id;
  final String title;
  final List<String> authors;
  final String? isbn;
  final String? publisher;
  final int pageCount;
  final String? coverUrl;

  /// Kullanıcının aldığı kısa not ("kaçırdım", "doğum günü hediyesi" ...).
  final String? note;

  final DateTime addedAt;
  final WishlistSource source;

  /// Depolamadan gelen tek kaydı ayrıştırır; id ve title zorunludur.
  /// Geçersiz kayıt `null` döner ve listede atlanır.
  static WishlistItemModel? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;

    final title = json['title'];
    if (title is! String || title.isEmpty) return null;

    return WishlistItemModel(
      id: id,
      title: title,
      authors: _stringList(json['authors']),
      isbn: _asStringOrNull(json['isbn']),
      publisher: _asStringOrNull(json['publisher']),
      pageCount: _asInt(json['pageCount']) ?? 0,
      coverUrl: _asStringOrNull(json['coverUrl']),
      note: _asStringOrNull(json['note']),
      addedAt: _parseDate(json['addedAt']) ?? DateTime.now(),
      source: WishlistSource.fromKey(json['source'] is String
          ? json['source'] as String
          : null),
    );
  }

  /// Geriye dönük uyumluluk için [tryFromJson] sarmalayıcısı.
  /// Bozuk kayıtlarda `FormatException` fırlatır.
  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    final item = tryFromJson(json);
    if (item == null) {
      throw const FormatException('Geçersiz satın alma kaydı: id/title eksik');
    }
    return item;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors,
        'isbn': isbn,
        'publisher': publisher,
        'pageCount': pageCount,
        'coverUrl': coverUrl,
        'note': note,
        'addedAt': addedAt.toIso8601String(),
        'source': source.key,
      };

  /// [note], [coverUrl] ve [isbn] için `null` verilirse alan temizlenir,
  /// hiç verilmezse eski değer korunur.
  WishlistItemModel copyWith({
    String? title,
    List<String>? authors,
    Object? isbn = _unset,
    String? publisher,
    int? pageCount,
    Object? coverUrl = _unset,
    Object? note = _unset,
    DateTime? addedAt,
    WishlistSource? source,
  }) {
    return WishlistItemModel(
      id: id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      isbn: identical(isbn, _unset) ? this.isbn : isbn as String?,
      publisher: publisher ?? this.publisher,
      pageCount: pageCount ?? this.pageCount,
      coverUrl:
          identical(coverUrl, _unset) ? this.coverUrl : coverUrl as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      addedAt: addedAt ?? this.addedAt,
      source: source ?? this.source,
    );
  }

  /// Kaydı doldurulmuş kitap formuna taşınabilir [BookModel]'e çevirir.
  /// Yeni kimlik üretilir; `isManual` true olarak işaretlenir.
  BookModel toBook() {
    return BookModel(
      id: BookModel.newId(),
      title: title,
      authors: authors,
      isbn: isbn,
      coverUrl: coverUrl,
      publisher: publisher,
      pageCount: pageCount,
      addedAt: DateTime.now(),
      isManual: true,
    );
  }

  /// Çakışmaya dayanıklı kimlik ([BookModel.newId] ile aynı üretici).
  static String newId() => BookModel.newId();

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<Object>()
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String? _asStringOrNull(Object? value) {
    if (value is! String) return null;
    return value.isEmpty ? null : value;
  }

  /// `as num?` String girdide TypeError fırlatır; savunmacı dönüşüm gerekli.
  static int? _asInt(Object? value) => value is num ? value.toInt() : null;

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  @override
  List<Object?> get props => [
        id,
        title,
        authors,
        isbn,
        publisher,
        pageCount,
        coverUrl,
        note,
        addedAt,
        source,
      ];
}

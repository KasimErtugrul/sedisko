import 'package:equatable/equatable.dart';

import 'book_model.dart';

/// Başkasından ödünç alınan kitap (1.18.0); kitaplık kaydı DEĞİLDİR
/// (sahibi başkasıdır, kitap `books_v1`'e girmez).
///
/// Kayıt tamamen bağımsızdır: başlık, yazarlar, kitabın sahibi, not,
/// alım tarihi ve dönüş tarihi (varsa) tutar. `returnedAt` `null` ise
/// kitap hâlâ kullanıcıda demektir ([isActive]).
const Object _unset = Object();

class BorrowedBookModel extends Equatable {
  const BorrowedBookModel({
    required this.id,
    required this.title,
    this.authors = const [],
    required this.owner,
    this.note,
    required this.borrowedAt,
    this.returnedAt,
  });

  final String id;
  final String title;

  /// Kitabın yazarları; eski/bozuk veride boş liste gelir.
  final List<String> authors;

  /// Kitabın sahibi (kimden alındı).
  final String owner;

  /// Kullanıcının isteğe bağlı notu ('Mehmet'ten aldım, okul kitabı' gibi).
  final String? note;

  /// Kitabın alındığı tarih.
  final DateTime borrowedAt;

  /// Geri verildiği tarih; `null` ise kitap hâlâ kullanıcıda.
  final DateTime? returnedAt;

  bool get isActive => returnedAt == null;

  /// Kart ve diyaloğun beklediği virgüllü düz metin ('A, B').
  String get authorsText => authors.join(', ');

  /// [note] ve [returnedAt] için `null` verilirse alan temizlenir,
  /// hiç verilmezse eski değer korunur (bkz. `BookModel.copyWith`).
  BorrowedBookModel copyWith({
    String? id,
    String? title,
    List<String>? authors,
    String? owner,
    Object? note = _unset,
    DateTime? borrowedAt,
    Object? returnedAt = _unset,
  }) {
    return BorrowedBookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      owner: owner ?? this.owner,
      note: identical(note, _unset) ? this.note : note as String?,
      borrowedAt: borrowedAt ?? this.borrowedAt,
      returnedAt: identical(returnedAt, _unset)
          ? this.returnedAt
          : returnedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'authors': authors,
        'owner': owner,
        'note': note,
        'borrowedAt': borrowedAt.toIso8601String(),
        'returnedAt': returnedAt?.toIso8601String(),
      };

  /// Depolamadan gelen tek kaydı savunmacı biçimde ayrıştırır:
  /// `id`/`title`/`owner` zorunlu ve boş olmayan String, `borrowedAt`
  /// zorunlu ISO8601 tarih; bozuk/eksik kayıtta `null` döner
  /// (bkz. `BookModel.tryFromJson`). `authors` savunmacı ayrıştırılır:
  /// liste değilse ya da bozuk öğeler varsa geçerliler korunur.
  static BorrowedBookModel? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final owner = json['owner'];
    if (id is! String || id.isEmpty) return null;
    if (title is! String || title.isEmpty) return null;
    if (owner is! String || owner.isEmpty) return null;

    final borrowedAt = _parseDate(json['borrowedAt']);
    if (borrowedAt == null) return null;

    DateTime? returnedAt;
    if (json['returnedAt'] is String) {
      returnedAt = DateTime.tryParse(json['returnedAt'] as String);
      if (returnedAt == null) return null;
    }

    final note = json['note'];
    return BorrowedBookModel(
      id: id,
      title: title,
      authors: _parseAuthors(json['authors']),
      owner: owner,
      note: note is String && note.isNotEmpty ? note : null,
      borrowedAt: borrowedAt,
      returnedAt: returnedAt,
    );
  }

  /// Geriye dönük uyumluluk için [tryFromJson] sarmalayıcısı.
  /// Bozuk kayıtlarda `FormatException` fırlatır.
  factory BorrowedBookModel.fromJson(Map<String, dynamic> json) {
    final item = tryFromJson(json);
    if (item == null) {
      throw const FormatException('Geçersiz ödünç alınan kitap kaydı');
    }
    return item;
  }

  /// Çakışmaya dayanıklı kimlik üretimi kitap modeliyle aynıdır.
  static String newId() => BookModel.newId();

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static List<String> _parseAuthors(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<Object>()
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  List<Object?> get props =>
      [id, title, authors, owner, note, borrowedAt, returnedAt];
}

import 'package:equatable/equatable.dart';

import 'book_model.dart';

/// Tek bir ödünç verme kaydı (1.18.0): kitaplıkta bir kitabın bir kişiye
/// verilmesi.
///
/// `bookTitle` bilinçli olarak kopyalanır: kitap silinse bile geçmiş
/// kayıt anlamlı kalır. `returnedAt` `null` ise ödünç hâlâ sürüyor
/// demektir ([isActive]). Kayıtlar bağımsızdır: aynı kitap birden çok
/// kişiye sırayla ya da üst üste verilebilir; her ödünç kendi kaydıdır.
const Object _unset = Object();

class LoanModel extends Equatable {
  const LoanModel({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.person,
    this.note,
    required this.lentAt,
    this.returnedAt,
  });

  final String id;

  /// Verilen kitabın kitaplıktaki kimliği; kitap silinse bile kayıt
  /// geçmişini korur.
  final String bookId;

  /// Kitabın o anki adının kopyası (geçmiş kayıt kitap silinse bile
  /// okunur kalır).
  final String bookTitle;

  /// Kitabın verildiği kişi.
  final String person;

  /// Kullanıcının isteğe bağlı notu ('2 haftada getirecek' gibi).
  final String? note;

  /// Kitabın verildiği tarih.
  final DateTime lentAt;

  /// Geri alındığı tarih; `null` ise ödünç sürüyor.
  final DateTime? returnedAt;

  bool get isActive => returnedAt == null;

  /// [note] ve [returnedAt] için `null` verilirse alan temizlenir,
  /// hiç verilmezse eski değer korunur (bkz. `BookModel.copyWith`).
  LoanModel copyWith({
    String? id,
    String? bookId,
    String? bookTitle,
    String? person,
    Object? note = _unset,
    DateTime? lentAt,
    Object? returnedAt = _unset,
  }) {
    return LoanModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      person: person ?? this.person,
      note: identical(note, _unset) ? this.note : note as String?,
      lentAt: lentAt ?? this.lentAt,
      returnedAt: identical(returnedAt, _unset)
          ? this.returnedAt
          : returnedAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'person': person,
        'note': note,
        'lentAt': lentAt.toIso8601String(),
        'returnedAt': returnedAt?.toIso8601String(),
      };

  /// Depolamadan gelen tek kaydı savunmacı biçimde ayrıştırır:
  /// `id`/`bookId`/`bookTitle`/`person` zorunlu ve boş olmayan String,
  /// `lentAt` zorunlu ISO8601 tarih; bozuk/eksik kayıtta `null` döner
  /// (bkz. `BookModel.tryFromJson`). `returnedAt` verilmiş ama
  /// ayrıştırılamamışsa kayıt belirsizdir ve düşürülür.
  static LoanModel? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final bookId = json['bookId'];
    final bookTitle = json['bookTitle'];
    final person = json['person'];
    if (id is! String || id.isEmpty) return null;
    if (bookId is! String || bookId.isEmpty) return null;
    if (bookTitle is! String || bookTitle.isEmpty) return null;
    if (person is! String || person.isEmpty) return null;

    final lentAt = _parseDate(json['lentAt']);
    if (lentAt == null) return null;

    DateTime? returnedAt;
    if (json['returnedAt'] is String) {
      returnedAt = DateTime.tryParse(json['returnedAt'] as String);
      if (returnedAt == null) return null;
    }

    final note = json['note'];
    return LoanModel(
      id: id,
      bookId: bookId,
      bookTitle: bookTitle,
      person: person,
      note: note is String && note.isNotEmpty ? note : null,
      lentAt: lentAt,
      returnedAt: returnedAt,
    );
  }

  /// Geriye dönük uyumluluk için [tryFromJson] sarmalayıcısı.
  /// Bozuk kayıtlarda `FormatException` fırlatır.
  factory LoanModel.fromJson(Map<String, dynamic> json) {
    final loan = tryFromJson(json);
    if (loan == null) {
      throw const FormatException('Geçersiz ödünç kaydı');
    }
    return loan;
  }

  /// Çakışmaya dayanıklı kimlik üretimi kitap modeliyle aynıdır.
  static String newId() => BookModel.newId();

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  @override
  List<Object?> get props =>
      [id, bookId, bookTitle, person, note, lentAt, returnedAt];
}

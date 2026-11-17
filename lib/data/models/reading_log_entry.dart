import 'package:equatable/equatable.dart';

/// Tek bir okuma olayı: o tarihte kullanıcının rapor ettiği sayfa konumu.
///
/// "Okumaya başla", "Sayfayı güncelle", "Bitirdim" ve "Yeniden oku"
/// aksiyonlarının her biri günlüğe bir kayıt ekler. Okunan sayfa miktarı
/// iki ardışık kayıt arasındaki farktan hesaplanır; bu yüzden kayıtlar
/// mutlak sayfa konumu tutar, miktarı değil.
class ReadingLogEntry extends Equatable {
  const ReadingLogEntry({required this.at, required this.page});

  /// Olayın gerçekleştiği tarih/saat.
  final DateTime at;

  /// O tarihte bulunduğu sayfa (0 = kitabın başı).
  final int page;

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'page': page,
      };

  /// Depolamadan gelen tek kaydı savunmacı biçimde ayrıştırır:
  /// bozuk/eksik kayıtlarda `null` döner (bkz. `BookModel.tryFromJson`).
  static ReadingLogEntry? tryFromJson(Map<String, dynamic> json) {
    final at = json['at'] is String ? DateTime.tryParse(json['at'] as String) : null;
    final page = json['page'] is num ? (json['page'] as num).toInt() : null;
    if (at == null || page == null || page < 0) return null;
    return ReadingLogEntry(at: at, page: page);
  }

  /// Geriye dönük uyumluluk için [tryFromJson] sarmalayıcısı.
  /// Bozuk kayıtlarda `FormatException` fırlatır.
  factory ReadingLogEntry.fromJson(Map<String, dynamic> json) {
    final entry = tryFromJson(json);
    if (entry == null) {
      throw const FormatException('Geçersiz okuma günlüğü kaydı');
    }
    return entry;
  }

  @override
  List<Object?> get props => [at, page];
}

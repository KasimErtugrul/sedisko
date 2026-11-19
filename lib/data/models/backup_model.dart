import 'dart:convert';

import '../models/book_model.dart';
import '../models/shelf_model.dart';

/// Yedek zarfı: kitaplık verisinin tamamını tek bir taşınabilir JSON
/// dosyasında toplar (WhatsApp/e-posta ile gönderilecek dosyanın içeriği).
///
/// Zarf ŞALON kurallarıyla çalışır:
/// - `format` etiketi dosyanın Kitaplığım yedeği olduğunu kanıtlar.
/// - `formatVersion` ileride alan eklenirse eski sürümlerin yeni yedekleri
///   reddetmesini sağlar (ileri uyumluluk): daha BÜYÜK sürüm reddedilir.
/// - Kitap ve raf kayıtları kendi savunmacı ayrıştırıcılarıyla
///   ([BookModel.tryFromJson], [ShelfModel.tryFromJson]) kayıt kayıt
///   doğrulanır; TEK bozuk kayıt tüm dosyayı geçersiz kılar — sessiz veri
///   kaybı yerine net bir hata tercih edilir.
/// - Taşıma planı (`organize_plan_v1`) ve kişisel tercihler (`settings_*`)
///   zarfa KOYULMAZ: plan geçici iş durumudur, tercihler cihazın
///   kullanıcısına aittir.
class BackupEnvelope {
  const BackupEnvelope({
    required this.exportedAt,
    required this.appVersion,
    required this.books,
    required this.shelves,
  });

  /// Dosyanın kimlik etiketi; farklı bir uygulamanın dosyası bu etiketle
  /// yanlışlıkla içe aktarılamaz.
  static const String formatTag = 'kitapligim-yedek';

  /// Zarf biçiminin sürümü. Yeni alan eklenirse 2'ye çıkar; eski
  /// uygulamalar daha yeni yedeği anlamlı bir hatayla reddeder.
  static const int formatVersion = 1;

  /// Yedeğin alındığı an; dosya adında da kullanılır.
  final DateTime exportedAt;

  /// Yedeği oluşturan uygulama sürümü (bilgi amaçlı).
  final String appVersion;
  final List<BookModel> books;
  final List<ShelfModel> shelves;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'format': formatTag,
        'formatVersion': formatVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'appVersion': appVersion,
        // İnsan tarafından okunabilir bilgi; içe aktarmada yeniden
        // hesaplandığı için buradaki değere güvenilmez.
        'counts': <String, int>{
          'books': books.length,
          'shelves': shelves.length,
        },
        'books': [for (final book in books) book.toJson()],
        'shelves': [for (final shelf in shelves) shelf.toJson()],
      };

  String encode() => jsonEncode(toJson());

  /// Zarfı doğrulayarak ayrıştırır. Başarısızlıkta kullanıcının göreceği
  /// Türkçe hata mesajıyla döner; hiçbir durumda istisna fırlatmaz.
  static BackupParseResult parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return BackupParseResult.fail(
        'Dosya okunamadı: geçerli bir JSON dosyası değil.',
      );
    }

    if (decoded is! Map) {
      return BackupParseResult.fail(
        'Dosya okunamadı: geçerli bir JSON dosyası değil.',
      );
    }
    final map = Map<String, dynamic>.from(decoded);

    if (map['format'] != formatTag) {
      return BackupParseResult.fail(
        'Bu dosya bir Kitaplığım yedeği değil.',
      );
    }

    final version = map['formatVersion'];
    if (version is! num) {
      return BackupParseResult.fail(
        'Yedek dosyasının sürümü okunamadı.',
      );
    }
    final versionInt = version.toInt();
    if (versionInt > formatVersion) {
      return BackupParseResult.fail(
        'Bu yedeği daha yeni bir uygulama sürümü oluşturdu. '
        'Lütfen uygulamayı güncelleyin ve yeniden deneyin.',
      );
    }
    if (versionInt < 1) {
      return BackupParseResult.fail(
        'Yedek dosyasının sürümü tanınamadı.',
      );
    }

    final booksRaw = map['books'];
    if (booksRaw is! List) {
      return BackupParseResult.fail('Yedekteki kitap listesi bozuk.');
    }
    final shelvesRaw = map['shelves'];
    if (shelvesRaw is! List) {
      return BackupParseResult.fail('Yedekteki raf listesi bozuk.');
    }

    final books = <BookModel>[];
    for (var i = 0; i < booksRaw.length; i++) {
      final item = booksRaw[i];
      if (item is! Map) {
        return BackupParseResult.fail(_badBook(i + 1));
      }
      final book = BookModel.tryFromJson(Map<String, dynamic>.from(item));
      if (book == null) {
        return BackupParseResult.fail(_badBook(i + 1));
      }
      books.add(book);
    }

    final shelves = <ShelfModel>[];
    for (var i = 0; i < shelvesRaw.length; i++) {
      final item = shelvesRaw[i];
      if (item is! Map) {
        return BackupParseResult.fail(_badShelf(i + 1));
      }
      final shelf = ShelfModel.tryFromJson(Map<String, dynamic>.from(item));
      if (shelf == null) {
        return BackupParseResult.fail(_badShelf(i + 1));
      }
      shelves.add(shelf);
    }

    final exportedAtRaw = map['exportedAt'];
    final exportedAt =
        exportedAtRaw is String ? DateTime.tryParse(exportedAtRaw) : null;
    final appVersionRaw = map['appVersion'];

    return BackupParseResult.ok(
      BackupEnvelope(
        exportedAt: exportedAt ?? DateTime.now(),
        appVersion: appVersionRaw is String ? appVersionRaw : '',
        books: books,
        shelves: shelves,
      ),
    );
  }

  static String _badBook(int position) =>
      'Yedekteki $position. kitap kaydı bozuk. Dosya içe aktarılamadı.';

  static String _badShelf(int position) =>
      'Yedekteki $position. raf kaydı bozuk. Dosya içe aktarılamadı.';
}

/// [BackupEnvelope.parse] sonucu: ya geçerli zarf ya da Türkçe hata.
class BackupParseResult {
  const BackupParseResult.ok(BackupEnvelope this.envelope)
      : error = null;

  const BackupParseResult.fail(String this.error) : envelope = null;

  final BackupEnvelope? envelope;
  final String? error;

  bool get isSuccess => envelope != null;
}

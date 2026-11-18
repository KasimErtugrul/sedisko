import 'dart:math';

import 'package:equatable/equatable.dart';

import 'reading_log_entry.dart';

enum ReadingStatus {
  notStarted('Başlanmadı'),
  reading('Okunuyor'),
  finished('Bitti');

  const ReadingStatus(this.label);

  final String label;
}

const Object _unset = Object();

class BookModel extends Equatable {
  const BookModel({
    required this.id,
    required this.title,
    required this.addedAt,
    this.authors = const [],
    this.isbn,
    this.coverUrl,
    this.coverPath,
    this.publisher,
    this.publishDate,
    this.pageCount = 0,
    this.shelf = '',
    this.status = ReadingStatus.notStarted,
    this.currentPage = 0,
    this.startedAt,
    this.finishedAt,
    this.notes,
    this.isManual = false,
    this.isFavorite = false,
    this.readingLog = const [],
    this.targetFinishDate,
  });

  final String id;
  final String title;
  final List<String> authors;
  final String? isbn;
  final String? coverUrl;

  /// Kullanıcının çektiği kitap fotoğrafının kalıcı dosya yolu
  /// (belgeler/covers/ altında). Eski veride bu alan yoktur; `null` gelir.
  /// Varsa ağ kapağından ([coverUrl]) önceliklidir.
  final String? coverPath;

  final String? publisher;
  final String? publishDate;
  final int pageCount;
  final String shelf;
  final ReadingStatus status;
  final int currentPage;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? notes;
  final bool isManual;

  /// Ana sayfadaki "Favoriler" bölümünde gösterilen işaret. Eski veride
  /// bu alan yoktur; varsayılan olarak kapalı gelir.
  final bool isFavorite;

  /// Tarihli okuma olayları (başlama, sayfa güncelleme, bitirme, yeniden
  /// okuma). Eski veride bu alan yoktur; bozuk kayıtlar ayrıştırılırken
  /// atlanır ve boş liste varsayılan olarak kullanılır.
  final List<ReadingLogEntry> readingLog;

  /// Kullanıcının kitabı bitirmeyi hedeflediği tarih (bitirme hedefi).
  /// Eski veride bu alan yoktur; `null` gelir. Kart, detay ve ana sayfa
  /// hedefe kalan günü ve günde okunması gereken sayfayı bundan üretir.
  final DateTime? targetFinishDate;

  final DateTime addedAt;

  static final Random _random = Random();
  static int _sequence = 0;

  /// Çakışmaya dayanıklı kimlik üretir.
  ///
  /// Yalnızca `microsecondsSinceEpoch` kullanmak, aynı mikro-saniyede
  /// oluşturulan iki kaydı (ör. çift tıklama sonrası iki kitap eklenirse)
  /// aynı kimlikle yazar; bu nedenle sıra sayacı ve rastgele bir ek
  /// eklenmiştir. Eski verideki yalnız-sayı kimlikler geçerliliğini korur.
  static String newId() {
    _sequence++;
    final ts = DateTime.now().microsecondsSinceEpoch;
    final seq = _sequence.toRadixString(36);
    final rand = _random.nextInt(1296).toRadixString(36).padLeft(2, '0');
    return '$ts-$seq$rand';
  }

  /// Manuel girişte kullanılan boş kitap.
  factory BookModel.blank({String? isbn}) => BookModel(
        id: newId(),
        title: '',
        addedAt: DateTime.now(),
        isbn: isbn,
        isManual: true,
      );

  /// Open Library `/api/books?jscmd=data` cevabındaki tek kayıttan üretir.
  factory BookModel.fromOpenLibrary(String isbn, Map<String, dynamic> json) {
    final authors = _names(json['authors']);
    final publishers = _names(json['publishers']);

    final cover = json['cover'];
    String? coverUrl;
    if (cover is Map) {
      coverUrl =
          (cover['medium'] ?? cover['large'] ?? cover['small'])?.toString();
    }

    return BookModel(
      id: newId(),
      title: (json['title'] ?? '').toString(),
      authors: authors,
      isbn: isbn,
      coverUrl: (coverUrl == null || coverUrl.isEmpty) ? null : coverUrl,
      publisher: publishers.isEmpty ? null : publishers.first,
      publishDate: json['publish_date']?.toString(),
      pageCount: _asInt(json['number_of_pages']) ?? 0,
      addedAt: DateTime.now(),
    );
  }

  /// Depolamadan gelen bozuk bir kaydı sessizce `[]`'e dönüştürmek yerine
  /// kayıt kayıt ayrıştırır: geçerli kayıtlar korunur, bozuk olanlar
  /// `null` döner (bkz. [BookLocalDataSource.getBooks]).
  static BookModel? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;

    final title = json['title'];
    final authors = json['authors'];

    return BookModel(
      id: id,
      title: title is String ? title : '',
      authors: authors is List
          ? authors
              .whereType<Object>()
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
          : const <String>[],
      isbn: _asStringOrNull(json['isbn']),
      coverUrl: _asStringOrNull(json['coverUrl']),
      coverPath: _asStringOrNull(json['coverPath']),
      publisher: _asStringOrNull(json['publisher']),
      publishDate: _asStringOrNull(json['publishDate']),
      pageCount: _asInt(json['pageCount']) ?? 0,
      shelf: json['shelf'] is String ? json['shelf'] as String : '',
      status: ReadingStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ReadingStatus.notStarted,
      ),
      currentPage: _asInt(json['currentPage']) ?? 0,
      startedAt: _parseDate(json['startedAt']),
      finishedAt: _parseDate(json['finishedAt']),
      notes: _asStringOrNull(json['notes']),
      isManual: json['isManual'] is bool ? json['isManual'] as bool : false,
      isFavorite: json['isFavorite'] is bool ? json['isFavorite'] as bool : false,
      readingLog: _parseLog(json['readingLog']),
      targetFinishDate: _parseDate(json['targetFinishDate']),
      addedAt: _parseDate(json['addedAt']) ?? DateTime.now(),
    );
  }

  /// Geriye dönük uyumluluk için [tryFromJson] sarmalayıcısı.
  /// Bozuk kayıtlarda `FormatException` fırlatır.
  factory BookModel.fromJson(Map<String, dynamic> json) {
    final book = tryFromJson(json);
    if (book == null) {
      throw const FormatException('Geçersiz kitap kaydı: id eksik');
    }
    return book;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors,
        'isbn': isbn,
        'coverUrl': coverUrl,
        'coverPath': coverPath,
        'publisher': publisher,
        'publishDate': publishDate,
        'pageCount': pageCount,
        'shelf': shelf,
        'status': status.name,
        'currentPage': currentPage,
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'notes': notes,
        'isManual': isManual,
        'isFavorite': isFavorite,
        if (readingLog.isNotEmpty)
          'readingLog': [for (final entry in readingLog) entry.toJson()],
        'targetFinishDate': targetFinishDate?.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
      };

  /// [startedAt] ve [finishedAt] için `null` verilirse tarih temizlenir,
  /// hiç verilmezse eski değer korunur.
  BookModel copyWith({
    String? title,
    List<String>? authors,
    String? isbn,
    String? coverUrl,
    Object? coverPath = _unset,
    String? publisher,
    String? publishDate,
    int? pageCount,
    String? shelf,
    ReadingStatus? status,
    int? currentPage,
    Object? startedAt = _unset,
    Object? finishedAt = _unset,
    String? notes,
    bool? isManual,
    bool? isFavorite,
    List<ReadingLogEntry>? readingLog,
    Object? targetFinishDate = _unset,
  }) {
    return BookModel(
      id: id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      isbn: isbn ?? this.isbn,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPath:
          identical(coverPath, _unset) ? this.coverPath : coverPath as String?,
      publisher: publisher ?? this.publisher,
      publishDate: publishDate ?? this.publishDate,
      pageCount: pageCount ?? this.pageCount,
      shelf: shelf ?? this.shelf,
      status: status ?? this.status,
      currentPage: currentPage ?? this.currentPage,
      startedAt:
          identical(startedAt, _unset) ? this.startedAt : startedAt as DateTime?,
      finishedAt: identical(finishedAt, _unset)
          ? this.finishedAt
          : finishedAt as DateTime?,
      notes: notes ?? this.notes,
      isManual: isManual ?? this.isManual,
      isFavorite: isFavorite ?? this.isFavorite,
      readingLog: readingLog ?? this.readingLog,
      targetFinishDate: identical(targetFinishDate, _unset)
          ? this.targetFinishDate
          : targetFinishDate as DateTime?,
      addedAt: addedAt,
    );
  }

  String get authorsText => authors.join(', ');

  double get progress {
    if (pageCount <= 0) return 0;
    return (currentPage / pageCount).clamp(0.0, 1.0).toDouble();
  }

  static List<String> _names(Object? field) {
    if (field is! List) return const <String>[];
    return field
        .whereType<Object>()
        .map((item) => item is Map ? item['name'] : item)
        .whereType<Object>()
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty && e != 'null')
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

  /// Günlük kayıtlarını kayıt kayıt ayrıştırır; bozuk bir kayıt tüm
  /// günlüğü değil yalnız kendisini düşürür.
  static List<ReadingLogEntry> _parseLog(Object? value) {
    if (value is! List) return const <ReadingLogEntry>[];
    return value
        .whereType<Map>()
        .map((m) => ReadingLogEntry.tryFromJson(Map<String, dynamic>.from(m)))
        .whereType<ReadingLogEntry>()
        .toList();
  }

  @override
  List<Object?> get props => [
        id,
        title,
        authors,
        isbn,
        coverUrl,
        coverPath,
        publisher,
        publishDate,
        pageCount,
        shelf,
        status,
        currentPage,
        startedAt,
        finishedAt,
        notes,
        isManual,
        isFavorite,
        readingLog,
        targetFinishDate,
        addedAt,
      ];
}

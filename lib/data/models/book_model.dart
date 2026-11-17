import 'package:equatable/equatable.dart';

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
  });

  final String id;
  final String title;
  final List<String> authors;
  final String? isbn;
  final String? coverUrl;
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
  final DateTime addedAt;

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

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
    final authors = (json['authors'] as List?)
            ?.map((a) => (a is Map ? a['name'] : null)?.toString())
            .whereType<String>()
            .toList() ??
        <String>[];

    final publishers = (json['publishers'] as List?)
            ?.map((p) => (p is Map ? p['name'] : null)?.toString())
            .whereType<String>()
            .toList() ??
        <String>[];

    final cover = json['cover'];
    String? coverUrl;
    if (cover is Map) {
      coverUrl = (cover['medium'] ?? cover['large'] ?? cover['small'])?.toString();
    }

    return BookModel(
      id: newId(),
      title: (json['title'] ?? '').toString(),
      authors: authors,
      isbn: isbn,
      coverUrl: coverUrl,
      publisher: publishers.isEmpty ? null : publishers.first,
      publishDate: json['publish_date']?.toString(),
      pageCount: (json['number_of_pages'] as num?)?.toInt() ?? 0,
      addedAt: DateTime.now(),
    );
  }

  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        authors: (json['authors'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        isbn: json['isbn'] as String?,
        coverUrl: json['coverUrl'] as String?,
        publisher: json['publisher'] as String?,
        publishDate: json['publishDate'] as String?,
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        shelf: json['shelf'] as String? ?? '',
        status: ReadingStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ReadingStatus.notStarted,
        ),
        currentPage: (json['currentPage'] as num?)?.toInt() ?? 0,
        startedAt: _parseDate(json['startedAt']),
        finishedAt: _parseDate(json['finishedAt']),
        notes: json['notes'] as String?,
        isManual: json['isManual'] as bool? ?? false,
        addedAt: _parseDate(json['addedAt']) ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authors': authors,
        'isbn': isbn,
        'coverUrl': coverUrl,
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
        'addedAt': addedAt.toIso8601String(),
      };

  /// [startedAt] ve [finishedAt] için `null` verilirse tarih temizlenir,
  /// hiç verilmezse eski değer korunur.
  BookModel copyWith({
    String? title,
    List<String>? authors,
    String? isbn,
    String? coverUrl,
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
  }) {
    return BookModel(
      id: id,
      title: title ?? this.title,
      authors: authors ?? this.authors,
      isbn: isbn ?? this.isbn,
      coverUrl: coverUrl ?? this.coverUrl,
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
      addedAt: addedAt,
    );
  }

  String get authorsText => authors.join(', ');

  double get progress {
    if (pageCount <= 0) return 0;
    return (currentPage / pageCount).clamp(0.0, 1.0).toDouble();
  }

  static DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  @override
  List<Object?> get props => [
        id,
        title,
        authors,
        isbn,
        coverUrl,
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
        addedAt,
      ];
}

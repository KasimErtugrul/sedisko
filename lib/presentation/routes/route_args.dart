import 'package:equatable/equatable.dart';

import '../../data/models/book_model.dart';

/// Form sayfasına verilen argüman.
/// [book] null ise boş (manuel) form açılır.
class BookFormArgs extends Equatable {
  const BookFormArgs({this.book, this.isEdit = false});

  final BookModel? book;
  final bool isEdit;

  @override
  List<Object?> get props => [book, isEdit];
}

/// Open Library başlık/yazar arama denetleyicisi.
///
/// 1.18.0: İki metin alanı (kitap adı / yazar) ve arama durumunu tutar;
/// sonuçlar [OpenLibraryRemoteDataSource.searchBooks] üzerinden çekilir.
/// Ağ hatası kullanıcıya gösterilecek Türkçe mesaj olarak [error]'e yazılır.
library;

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/errors/app_exceptions.dart';
import '../../data/datasources/open_library_remote_datasource.dart';
import '../../data/models/open_library_search_result.dart';

class OpenLibrarySearchController extends GetxController {
  OpenLibrarySearchController(this._remote);

  final OpenLibraryRemoteDataSource _remote;

  final titleCtrl = TextEditingController();
  final authorCtrl = TextEditingController();

  final searching = false.obs;
  final searched = false.obs;
  final results = <OpenLibrarySearchResult>[].obs;
  final error = ''.obs;

  /// Her iki alan boşsa hata mesajı yazılır ve sonuçlar temizlenir;
  /// doluysa arama yapılır. Ağ hatasında mesaj [error]'e yazılır ve
  /// sonuçlar temizlenir; başarıda hata temizlenir ve sonuçlar listelenir.
  Future<void> search() async {
    final title = titleCtrl.text.trim();
    final author = authorCtrl.text.trim();

    if (title.isEmpty && author.isEmpty) {
      error.value = 'En az bir alanı doldurun.';
      results.clear();
      searched.value = false;
      return;
    }

    searching.value = true;
    error.value = '';
    try {
      final found = await _remote.searchBooks(
        title: title.isEmpty ? null : title,
        author: author.isEmpty ? null : author,
      );
      results.assignAll(found);
      searched.value = true;
      error.value = '';
    } on NetworkException catch (exception) {
      results.clear();
      searched.value = false;
      error.value = exception.message;
    } finally {
      searching.value = false;
    }
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    authorCtrl.dispose();
    super.onClose();
  }
}

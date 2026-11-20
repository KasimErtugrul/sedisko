/// Satın alınacaklar listesinin denetleyicisi.
///
/// 1.18.0: Depodaki ([WishlistLocalDataSource]) kayıtları bellekte
/// [RxList] olarak tutar; ekleme/güncelleme/silme işlemleri yazma kilidi
/// arkasında depoya yazılır ve bellek yeniden yüklenir. Aynı ISBN (veya
/// ISBN'sizlerde başlık+yazar anahtarı) ikinci kez eklenmez; kullanıcıya
/// [onNotify] ile bilgi verilir.
library;

import 'package:get/get.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/text_normalizer.dart';
import '../../data/datasources/wishlist_local_datasource.dart';
import '../../data/models/open_library_search_result.dart';
import '../../data/models/wishlist_item_model.dart';

class WishlistController extends GetxController {
  WishlistController({
    required WishlistLocalDataSource store,
    void Function(String, String)? onNotify,
  })  : _store = store,
        _onNotify = onNotify;

  final WishlistLocalDataSource _store;
  final void Function(String, String)? _onNotify;

  /// En yeni önce sıralı liste ([WishlistLocalDataSource.getItems] sırası).
  final items = <WishlistItemModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Depodan yeniden yükler; başarısız olursa liste değişmez.
  Future<void> load() async {
    items.assignAll(_store.getItems());
  }

  /// Kaydı listeye ekler. Aynı ISBN (ISBN'sizlerde başlık+yazar anahtarı)
  /// listede varsa eklemez, kullanıcıya haber verir ve `false` döner.
  Future<bool> add(WishlistItemModel item) async {
    if (_isDuplicate(item)) {
      _notify('Zaten listede', '"${item.title}" satın alma listesinde.');
      return false;
    }
    if (!await _persist(() => _store.upsert(item))) return false;
    items.assignAll(_store.getItems());
    return true;
  }

  /// Open Library arama sonucunu kaynak bilgisiyle listeye ekler;
  /// ISBN/yayınevi/sayfa/kapak bilgileri taşınır.
  Future<bool> addFromSearch(OpenLibrarySearchResult result,
      {String? note}) {
    final book = result.toBook();
    return add(
      WishlistItemModel(
        id: WishlistItemModel.newId(),
        title: book.title,
        authors: book.authors,
        isbn: book.isbn,
        publisher: book.publisher,
        pageCount: book.pageCount,
        coverUrl: book.coverUrl,
        note: note,
        addedAt: DateTime.now(),
        source: WishlistSource.openlibrary,
      ),
    );
  }

  /// Var olan kaydı günceller (id değişmez; liste sırası korunur).
  Future<bool> updateItem(WishlistItemModel item) async {
    if (!await _persist(() => _store.upsert(item))) return false;
    items.assignAll(_store.getItems());
    return true;
  }

  /// Kaydı listeden çıkarır.
  Future<bool> remove(String id) async {
    if (!await _persist(() => _store.remove(id))) return false;
    items.assignAll(_store.getItems());
    return true;
  }

  /// Yazma işlemini çalıştırır; depo hatasında kullanıcıya haber verir
  /// ve `false` döner.
  Future<bool> _persist(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on StorageException catch (error) {
      _notify('Kaydedilemedi', error.message);
      return false;
    }
  }

  /// Aynı ISBN ya da (ISBN yoksa) aynı başlık+yazar anahtarı listede
  /// var mı? Türkçe İ/ı ve aksan farklarına duyarsız anahtar kullanılır.
  bool _isDuplicate(WishlistItemModel candidate) {
    final isbn = candidate.isbn;
    if (isbn != null && isbn.isNotEmpty) {
      return items.any(
        (item) => item.isbn != null && item.isbn == isbn,
      );
    }
    final key = _manualKey(candidate);
    return items.any(
      (item) =>
          (item.isbn == null || item.isbn!.isEmpty) &&
          _manualKey(item) == key,
    );
  }

  String _manualKey(WishlistItemModel item) {
    final authors = item.authors.map(TextNormalizer.searchKey).toList()
      ..sort();
    return '${TextNormalizer.searchKey(item.title.trim())}|${authors.join(',')}';
  }

  void _notify(String title, String message) =>
      _onNotify?.call(title, message);
}

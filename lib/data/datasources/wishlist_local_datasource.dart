import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/wishlist_item_model.dart';

/// Satın alınacaklar listesi tek bir JSON liste olarak SharedPreferences'ta
/// tutulur ([StorageKeys.wishlist]).
///
/// Güvenlik notları (kitaplık datasource'u ile aynı desen):
/// - Bozuk *tek* kayıt tüm listeyi silmez; geçerli kayıtlar korunur.
/// - Okuma-güncelleme-yazma döngüsü sıraya alınır (_lock); paralel iki
///   kayıt birbirinin üstüne yazmaz (lost-update problemi).
class WishlistLocalDataSource {
  WishlistLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Sıraya alınmış yazma işlemleri.
  Future<void>? _lock;

  /// Kayıtları eklenme tarihi AZALAN (en yeni önce) sıralı döner.
  /// Bozuk blok → boş liste; bozuk tek kayıt atlanır.
  List<WishlistItemModel> getItems() {
    final raw = _prefs.getString(StorageKeys.wishlist);
    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> list;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      list = decoded;
    } on FormatException {
      // Tüm blok bozuksa kayıt yokmuş gibi davran; yazma sırasında
      // üzerine sağlıklı bir liste yazılacaktır.
      return [];
    } on TypeError {
      return [];
    }

    final items = <WishlistItemModel>[];
    for (final item in list) {
      if (item is! Map) continue;
      final model =
          WishlistItemModel.tryFromJson(Map<String, dynamic>.from(item));
      if (model != null) items.add(model);
    }
    // En yeni önce: kullanıcı liste başında son eklediğini görür.
    items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return items;
  }

  Future<void> upsert(WishlistItemModel item) {
    return _runSerialized(() async {
      final items = getItems();
      final index = items.indexWhere((i) => i.id == item.id);
      if (index >= 0) {
        items[index] = item;
      } else {
        items.add(item);
      }
      await _write(items);
    });
  }

  Future<void> remove(String id) {
    return _runSerialized(() async {
      final items = getItems()..removeWhere((i) => i.id == id);
      await _write(items);
    });
  }

  /// "Üzerine yaz" içe aktarması: listeyi komple değiştirir.
  /// Yalnızca yedek dosyası uçtan uca doğrulandıktan sonra çağrılmalıdır.
  Future<void> replaceAll(List<WishlistItemModel> items) {
    return _runSerialized(() async => _write(items));
  }

  Future<void> _runSerialized(Future<void> Function() action) {
    final previous = _lock ?? Future<void>.value();
    final task = previous.catchError((Object _) {}).then((_) => action());
    // Bir işlem hata verirse kuyruk bozulmasın: hatayı yut, sıradaki işlem
    // yine de çalışabilsin. Hata, çağırana [task] üzerinden iletilir.
    _lock = task.catchError((Object _) {});
    return task;
  }

  Future<void> _write(List<WishlistItemModel> items) async {
    final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
    try {
      final ok = await _prefs.setString(StorageKeys.wishlist, encoded);
      if (!ok) {
        throw const StorageException(
          'Satın alma listesi kaydedilemedi. Depolama alanını kontrol edin.',
        );
      }
    } on StorageException {
      rethrow;
    } catch (error) {
      throw StorageException(
        'Satın alma listesi kaydedilemedi. Depolama alanını kontrol edin.',
        cause: error,
      );
    }
  }
}

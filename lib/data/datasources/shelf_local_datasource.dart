import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/organize_plan_model.dart';
import '../models/shelf_model.dart';

/// Raf tanımları (`shelves_v1`) ve taşıma planı (`organize_plan_v1`)
/// için kalıcı depo.
///
/// `books_v1` buraya DOKUNMAZ: kitapların raf ataması kitap kaydının
/// içindeki `shelf` alanında yaşamaya devam eder. Bu depo yalnızca
/// fiziksel raf tanımını ve sürüyor olan planı tutar.
///
/// Savunmacı ayrıştırma: bozuk *tek* kayıt atlanır, bozuk *blok* boş
/// liste/plan döner; yazma üzerine sağlıklı veri yazacaktır.
class ShelfLocalDataSource {
  ShelfLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Raflar fiziksel sıraya göre (order) döner.
  List<ShelfModel> getShelves() {
    final raw = _prefs.getString(StorageKeys.shelves);
    if (raw == null || raw.isEmpty) return [];

    final List<dynamic> list;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      list = decoded;
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }

    final shelves = <ShelfModel>[];
    for (final item in list) {
      if (item is! Map) continue;
      final shelf =
          ShelfModel.tryFromJson(Map<String, dynamic>.from(item));
      if (shelf != null) shelves.add(shelf);
    }
    shelves.sort((a, b) => a.order.compareTo(b.order));
    return shelves;
  }

  Future<void> saveShelves(List<ShelfModel> shelves) async {
    final encoded =
        jsonEncode([for (final shelf in shelves) shelf.toJson()]);
    final ok = await _prefs.setString(StorageKeys.shelves, encoded);
    if (!ok) {
      throw const FormatException('Raf tanımları kaydedilemedi.');
    }
  }

  OrganizePlanModel? getPlan() {
    final raw = _prefs.getString(StorageKeys.organizePlan);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return OrganizePlanModel.tryFromJson(
        Map<String, dynamic>.from(decoded),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// [plan] `null` verilirse plan anahtarı silinir (plan bitti ya da
  /// iptal edildi).
  Future<void> savePlan(OrganizePlanModel? plan) async {
    if (plan == null) {
      await _prefs.remove(StorageKeys.organizePlan);
      return;
    }
    final encoded = jsonEncode(plan.toJson());
    final ok = await _prefs.setString(StorageKeys.organizePlan, encoded);
    if (!ok) {
      throw const FormatException('Taşıma planı kaydedilemedi.');
    }
  }
}

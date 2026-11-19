import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../models/organize_plan_model.dart';
import '../models/shelf_model.dart';

/// Raf tanımları (`shelves_v1`), taşıma planı (`organize_plan_v1`) ve
/// düzen asistanının kişisel tercihleri (favori raf/yazarlar, kalınlık
/// hesabı) için kalıcı depo.
///
/// `books_v1` buraya DOKUNMAZ: kitapların raf ataması kitap kaydının
/// içindeki `shelf` alanında yaşamaya devam eder. Bu depo yalnızca
/// fiziksel raf tanımını, sürüyor olan planı ve asistan tercihlerini
/// tutar.
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

  // ---------- Düzen asistanı tercihleri (1.15.0) ----------

  /// Favori raf kimliği; hiç seçilmediyse `null`.
  String? getFavoriteShelfId() => _prefs.getString(SettingsKeys.favoriteShelfId);

  /// [id] `null` verilirse tercih silinir ('Yok' seçimi).
  Future<void> saveFavoriteShelfId(String? id) async {
    if (id == null) {
      await _prefs.remove(SettingsKeys.favoriteShelfId);
      return;
    }
    await _prefs.setString(SettingsKeys.favoriteShelfId, id);
  }

  /// Favori yazarlar; bozuk kalıcı veride boş liste döner. Kayıtlar
  /// kırpılır, boşlar ve yinelenenler (Türkçe katlamayla) atılır.
  List<String> getFavoriteAuthors() {
    final raw = _prefs.getStringList(SettingsKeys.favoriteAuthors);
    if (raw == null) return [];
    return _sanitizeAuthors(raw);
  }

  Future<void> saveFavoriteAuthors(List<String> authors) async {
    final ok = await _prefs.setStringList(
      SettingsKeys.favoriteAuthors,
      _sanitizeAuthors(authors),
    );
    if (!ok) {
      throw const FormatException('Favori yazarlar kaydedilemedi.');
    }
  }

  /// Kalınlık hesabı açık mı? Anahtar yoksa varsayılan AÇIK gelir:
  /// kalın kitapların sığmadığı gözlemi varsayılan davranışı değiştirir.
  bool getThicknessAware() =>
      _prefs.getBool(SettingsKeys.thicknessAware) ?? true;

  Future<void> saveThicknessAware(bool value) async {
    await _prefs.setBool(SettingsKeys.thicknessAware, value);
  }

  static List<String> _sanitizeAuthors(List<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final item in raw) {
      final name = item.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!seen.add(key)) continue;
      result.add(name);
    }
    return result;
  }
}

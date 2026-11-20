import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raf modeli ve kalıcı deposu: JSON dönüşümü, savunmacı ayrıştırma,
/// bozuk kayıtların atlanması, eski kapasite verisinin cm'ye geçişi.
void main() {
  group('ShelfModel', () {
    test('json dönüşümü tur atlatır', () {
      const shelf = ShelfModel(
        id: 's1',
        name: 'Salon - 2. raf',
        lengthCm: 125,
        location: 'Alt kat',
        order: 3,
      );
      final restored = ShelfModel.tryFromJson(shelf.toJson());
      expect(restored, shelf);
    });

    test('toJson eski capacity alanını da yazar (geriye dönük uyum)', () {
      const shelf = ShelfModel(
        id: 's1',
        name: 'A',
        lengthCm: 125,
        order: 0,
      );
      expect(shelf.toJson()['lengthCm'], 125);
      // 125 cm ≈ 50 kitap (eski gösterim; yalnız uyumluluk içindir).
      expect(shelf.toJson()['capacity'], shelf.booksCapacity);
      expect(shelf.booksCapacity, 50);
    });

    test('ESKİ VERİ: yalnız capacity\'li kayıt cm\'ye çevrilir', () {
      // 1.18 ve öncesi: kapasite kitap sayısıydı; 1 normal kitap ≈ 2,5 cm.
      final migrated = ShelfModel.tryFromJson({
        'id': 's1',
        'name': 'Kitaplık',
        'capacity': 50,
        'order': 0,
      });
      expect(migrated!.lengthCm, 125); // 50 × 2,5 cm
      expect(migrated.location, '');
    });

    test('ESKİ VERİ: lengthCm varsa capacity yok sayılır', () {
      final shelf = ShelfModel.tryFromJson({
        'id': 's1',
        'name': 'Kitaplık',
        'lengthCm': 90,
        'capacity': 50,
        'order': 0,
      });
      expect(shelf!.lengthCm, 90);
    });

    test('id boşsa kayıt geçersizdir', () {
      expect(
        ShelfModel.tryFromJson({
          'id': '',
          'name': 'Raf',
          'lengthCm': 10,
          'order': 0,
        }),
        isNull,
      );
      expect(
        ShelfModel.tryFromJson({'name': 'Raf', 'lengthCm': 10, 'order': 0}),
        isNull,
      );
    });

    test('ad boşsa kayıt geçersizdir', () {
      expect(
        ShelfModel.tryFromJson({'id': 's1', 'name': '  ', 'order': 0}),
        isNull,
      );
    });

    test('uzunluk okunamazsa varsayılanla gelir', () {
      final shelf = ShelfModel.tryFromJson({
        'id': 's1',
        'name': 'Raf',
        'order': 0,
      });
      expect(shelf!.lengthCm, ShelfModel.defaultLengthCm);
      expect(shelf.lengthCm, 100);
      expect(shelf.location, '');
      expect(shelf.order, 0);
    });

    test('eksik yer/sıra alanları varsayılanla gelir', () {
      final shelf = ShelfModel.tryFromJson({
        'id': 's1',
        'name': 'Raf',
        'lengthCm': 80,
      });
      expect(shelf!.location, '');
      expect(shelf.order, 0);
      expect(shelf.lengthMm, 800);
    });
  });

  group('ShelfLocalDataSource', () {
    test('raflar kaydedilir ve fiziksel sırayla okunur', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ShelfLocalDataSource(prefs);

      await store.saveShelves([
        const ShelfModel(id: 's2', name: 'B', lengthCm: 60, order: 1),
        const ShelfModel(id: 's1', name: 'A', lengthCm: 40, order: 0),
      ]);

      final loaded = store.getShelves();
      expect(loaded.map((s) => s.name).toList(), ['A', 'B']);
    });

    test('ESKİ VERİ: capacity-only JSON kayıpsız okunur', () async {
      SharedPreferences.setMockInitialValues({
        'shelves_v1':
            '[{"id":"s1","name":"A","capacity":3,"location":"Alt kat","order":0},'
            '{"id":"","name":"Bozuk","capacity":1,"order":1},'
            '{"id":"s2","name":"B","capacity":7,"order":1}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = ShelfLocalDataSource(prefs);

      final shelves = store.getShelves();
      expect(shelves.map((s) => s.name).toList(), ['A', 'B']);
      // 3 kitap ≈ 7,5 cm → 8 cm; 7 kitap ≈ 17,5 cm → 18 cm.
      expect(shelves.firstWhere((s) => s.name == 'A').lengthCm, 8);
      expect(shelves.firstWhere((s) => s.name == 'B').lengthCm, 18);
    });

    test('bozuk blok boş liste döner', () async {
      SharedPreferences.setMockInitialValues({'shelves_v1': '[[[[['});
      final prefs = await SharedPreferences.getInstance();
      expect(ShelfLocalDataSource(prefs).getShelves(), isEmpty);
    });
  });
}

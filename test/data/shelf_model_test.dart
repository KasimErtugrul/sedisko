import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raf modeli ve kalıcı deposu: JSON dönüşümü, savunmacı ayrıştırma,
/// bozuk kayıtların atlanması.
void main() {
  group('ShelfModel', () {
    test('json dönüşümü tur atlatır', () {
      const shelf = ShelfModel(
        id: 's1',
        name: 'Salon - 2. raf',
        capacity: 50,
        location: 'Alt kat',
        order: 3,
      );
      final restored = ShelfModel.tryFromJson(shelf.toJson());
      expect(restored, shelf);
    });

    test('id boşsa kayıt geçersizdir', () {
      expect(
        ShelfModel.tryFromJson({
          'id': '',
          'name': 'Raf',
          'capacity': 10,
          'order': 0,
        }),
        isNull,
      );
      expect(
        ShelfModel.tryFromJson({'name': 'Raf', 'capacity': 10, 'order': 0}),
        isNull,
      );
    });

    test('ad boşsa kayıt geçersizdir; kapasite 1"in altına çekilir', () {
      expect(
        ShelfModel.tryFromJson({'id': 's1', 'name': '  ', 'order': 0}),
        isNull,
      );
      final fixed = ShelfModel.tryFromJson({
        'id': 's1',
        'name': 'Raf',
        'capacity': 0,
        'order': 0,
      });
      expect(fixed!.capacity, 1);
    });

    test('eksik alanlar varsayılanla gelir', () {
      final shelf = ShelfModel.tryFromJson({
        'id': 's1',
        'name': 'Raf',
        'capacity': 12,
      });
      expect(shelf!.location, '');
      expect(shelf.order, 0);
    });
  });

  group('ShelfLocalDataSource', () {
    test('raflar kaydedilir ve fiziksel sırayla okunur', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ShelfLocalDataSource(prefs);

      await store.saveShelves([
        const ShelfModel(id: 's2', name: 'B', capacity: 5, order: 1),
        const ShelfModel(id: 's1', name: 'A', capacity: 3, order: 0),
      ]);

      final loaded = store.getShelves();
      expect(loaded.map((s) => s.name).toList(), ['A', 'B']);
    });

    test('bozuk tek kayıt atlanır, sağlamlar korunur', () async {
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
    });

    test('bozuk blok boş liste döner', () async {
      SharedPreferences.setMockInitialValues({'shelves_v1': '[[[[['});
      final prefs = await SharedPreferences.getInstance();
      expect(ShelfLocalDataSource(prefs).getShelves(), isEmpty);
    });
  });
}

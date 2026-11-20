import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/core/errors/app_exceptions.dart';
import 'package:kitaplik/data/datasources/wishlist_local_datasource.dart';
import 'package:kitaplik/data/models/wishlist_item_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WishlistLocalDataSource: upsert/get sıralama (en yeni önce), remove,
/// bozuk veri dayanıklılığı ve yazma hatası (1.18.0).
void main() {
  late SharedPreferences prefs;
  late WishlistLocalDataSource dataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    dataSource = WishlistLocalDataSource(prefs);
  });

  WishlistItemModel item(
    String id, {
    String title = 'Kitap',
    DateTime? addedAt,
  }) =>
      WishlistItemModel(
        id: id,
        title: title,
        addedAt: addedAt ?? DateTime(2024, 1, 1),
      );

  group('upsert / getItems', () {
    test('yeni kayıt ekler', () async {
      await dataSource.upsert(item('1', title: 'Dune'));
      expect(dataSource.getItems().map((i) => i.id), ['1']);
    });

    test('aynı id ile çağrılırsa üzerine yazar (upsert)', () async {
      await dataSource.upsert(item('1', title: 'Eski'));
      await dataSource.upsert(item('1', title: 'Yeni'));

      final items = dataSource.getItems();
      expect(items.length, 1);
      expect(items.first.title, 'Yeni');
    });

    test('eklenme tarihi AZALAN sıralı döner (en yeni önce)', () async {
      await dataSource.upsert(item('eski', addedAt: DateTime(2024, 1, 1)));
      await dataSource.upsert(item('yeni', addedAt: DateTime(2025, 6, 1)));
      await dataSource.upsert(item('orta', addedAt: DateTime(2024, 12, 1)));

      expect(dataSource.getItems().map((i) => i.id), ['yeni', 'orta', 'eski']);
    });

    test('paralel çağrılar veri kaybettirmez (yazma kuyruğu)', () async {
      await Future.wait([
        dataSource.upsert(item('1', title: 'Birinci')),
        dataSource.upsert(item('2', title: 'İkinci')),
        dataSource.upsert(item('3', title: 'Üçüncü')),
      ]);

      expect(dataSource.getItems().length, 3);
    });
  });

  group('remove', () {
    test('kaydı siler', () async {
      await dataSource.upsert(item('1'));
      await dataSource.upsert(item('2'));
      await dataSource.remove('1');

      expect(dataSource.getItems().map((i) => i.id), ['2']);
    });

    test('olmayan id silme isteği hatasız geçer', () async {
      await dataSource.upsert(item('1'));
      await dataSource.remove('yok');
      expect(dataSource.getItems().length, 1);
    });
  });

  group('bozuk veri dayanıklılığı', () {
    test('tamamen bozuk JSON bloğu için boş liste döner', () async {
      await prefs.setString('wishlist_v1', '[[[bu-json-degil');
      expect(dataSource.getItems(), isEmpty);
    });

    test('tek bozuk kayıt diğerlerini silmez', () async {
      const corrupted = '''
      [
        {"id": "1", "title": "Sağlam Kayıt", "addedAt": "2026-01-03T10:00:00.000"},
        {"title": "idsiz bozuk kayıt"},
        {"id": "", "title": "boş id"},
        {"id": "2", "title": "İkinci Sağlam", "source": "openlibrary", "addedAt": "2026-01-01T10:00:00.000"}
      ]
      ''';
      await prefs.setString('wishlist_v1', corrupted);

      final items = dataSource.getItems();
      // En yeni önce.
      expect(items.map((i) => i.id).toList(), ['1', '2']);
      expect(items.last.source, WishlistSource.openlibrary);
    });

    test('kök liste değil Map gelseydi boş liste döner', () async {
      await prefs.setString('wishlist_v1', '{"id": "1"}');
      expect(dataSource.getItems(), isEmpty);
    });

    test('anahtar hiç yoksa boş liste döner', () {
      expect(dataSource.getItems(), isEmpty);
    });
  });

  group('yazma hataları', () {
    test('yazma başarısızsa StorageException fırlatır', () async {
      final failingSource = WishlistLocalDataSource(_FailingPrefs(prefs));

      await expectLater(
        failingSource.upsert(item('1')),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        failingSource.remove('1'),
        throwsA(isA<StorageException>()),
      );
    });
  });
}

/// Sadece test için: setString'i false dönen SharedPreferences sarmalayıcı.
class _FailingPrefs implements SharedPreferences {
  _FailingPrefs(this._inner);

  final SharedPreferences _inner;

  @override
  Future<bool> setString(String key, String value) async => false;

  // Kalan üyeler iç sarmalayıcıya devredilir.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #getString
          ? _inner.getString(invocation.positionalArguments[0] as String)
          : super.noSuchMethod(invocation);
}

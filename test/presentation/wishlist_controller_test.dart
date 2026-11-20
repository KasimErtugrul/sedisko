import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/datasources/wishlist_local_datasource.dart';
import 'package:kitaplik/data/models/open_library_search_result.dart';
import 'package:kitaplik/data/models/wishlist_item_model.dart';
import 'package:kitaplik/presentation/controllers/wishlist_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WishlistController: ekleme/tekilleştirme (ISBN veya başlık+yazar),
/// aramadan ekleme, güncelleme, silme ve depo hatası davranışı (1.18.0).
void main() {
  late SharedPreferences prefs;
  late List<String> notifications;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    notifications = [];
  });

  WishlistController build({SharedPreferences? prefsOverride}) {
    return WishlistController(
      store: WishlistLocalDataSource(prefsOverride ?? prefs),
      onNotify: (title, message) =>
          notifications.add('$title|$message'),
    );
  }

  WishlistItemModel item(
    String id, {
    String title = 'Dune',
    List<String> authors = const ['Frank Herbert'],
    String? isbn,
    DateTime? addedAt,
  }) =>
      WishlistItemModel(
        id: id,
        title: title,
        authors: authors,
        isbn: isbn,
        addedAt: addedAt ?? DateTime(2026, 1, 1),
      );

  group('add', () {
    test('yeni kaydı ekler ve true döner', () async {
      final controller = build();

      final ok = await controller.add(item('w1', isbn: '9780441172719'));

      expect(ok, isTrue);
      expect(controller.items.length, 1);
      expect(controller.items.first.id, 'w1');
    });

    test('aynı ISBN ikinci kez eklenmez, false + bildirim', () async {
      final controller = build();
      await controller.add(item('w1', isbn: '9780441172719'));

      final ok = await controller.add(
        item('w2', isbn: '9780441172719', title: 'Dune (başka baskı)'),
      );

      expect(ok, isFalse);
      expect(controller.items.length, 1);
      expect(notifications, ['Zaten listede|"Dune (başka baskı)" satın alma listesinde.']);
    });

    test('ISBN\'sizlerde başlık+yazar anahtarıyla tekilleştirir', () async {
      final controller = build();
      await controller.add(item(
        'w1',
        title: 'İstanbul Hatırası',
        authors: const ['Ahmet Ümit'],
      ));

      // Türkçe İ/ı ve boşluk farkına duyarsız.
      final ok = await controller.add(item(
        'w2',
        title: 'istanbul hatırası',
        authors: const ['Ahmet Ümit'],
      ));

      expect(ok, isFalse);
      expect(controller.items.length, 1);
      expect(notifications, isNotEmpty);
    });

    test('ISBN\'siz farklı başlık eklenir', () async {
      final controller = build();
      await controller.add(item('w1', title: 'Dune'));

      final ok = await controller.add(item('w2', title: 'Simyacı'));

      expect(ok, isTrue);
      expect(controller.items.length, 2);
    });

    test('ISBN\'sizler, ISBN\'li kayıtla çakışmaz', () async {
      final controller = build();
      await controller.add(item('w1', title: 'Dune'));

      final ok = await controller.add(item('w2', title: 'Dune', isbn: '978x'));

      expect(ok, isTrue);
      expect(controller.items.length, 2);
    });

    test('depo yazma hatasında false + bildirim, liste değişmez', () async {
      SharedPreferences.setMockInitialValues({});
      final failingPrefs = _FailingPrefs(await SharedPreferences.getInstance());
      final controller = build(prefsOverride: failingPrefs);

      final ok = await controller.add(item('w1'));

      expect(ok, isFalse);
      expect(controller.items, isEmpty);
      expect(notifications, isNotEmpty);
      expect(notifications.first, startsWith('Kaydedilemedi'));
    });
  });

  group('addFromSearch', () {
    test('arama sonucu openlibrary kaynağıyla eklenir', () async {
      final controller = build();
      final result = OpenLibrarySearchResult(
        title: 'Dune',
        authors: ['Frank Herbert'],
        firstPublishYear: 1965,
        coverId: 846192,
        isbns: ['0140328726', '9780140328721'],
        publishers: ['Chilton Books'],
        pageCount: 412,
      );

      final ok = await controller.addFromSearch(result);

      expect(ok, isTrue);
      final stored = controller.items.single;
      expect(stored.source, WishlistSource.openlibrary);
      expect(stored.title, 'Dune');
      expect(stored.isbn, '9780140328721');
      expect(stored.publisher, 'Chilton Books');
      expect(stored.pageCount, 412);
      expect(stored.coverUrl, 'https://covers.openlibrary.org/b/id/846192-M.jpg');
    });

    test('not taşınır', () async {
      final controller = build();

      await controller.addFromSearch(
        OpenLibrarySearchResult(title: 'Dune'),
        note: 'kaçırdım',
      );

      expect(controller.items.single.note, 'kaçırdım');
    });

    test('aynı ISBN aramadan tekrar eklenmez', () async {
      final controller = build();
      await controller.addFromSearch(OpenLibrarySearchResult(
        title: 'Dune',
        isbns: ['9780140328721'],
      ));

      final ok = await controller.addFromSearch(OpenLibrarySearchResult(
        title: 'Dune',
        isbns: ['9780140328721'],
      ));

      expect(ok, isFalse);
      expect(controller.items.length, 1);
      expect(notifications.first, startsWith('Zaten listede'));
    });
  });

  group('updateItem / remove', () {
    test('güncelleme depoya yazılır', () async {
      final controller = build();
      await controller.add(item('w1', title: 'Eski'));

      final ok = await controller.updateItem(
        item('w1', title: 'Yeni').copyWith(note: 'yeni not'),
      );

      expect(ok, isTrue);
      expect(controller.items.single.title, 'Yeni');
      expect(controller.items.single.note, 'yeni not');

      // Depoya gerçekten yazıldı mı?
      final fresh = WishlistLocalDataSource(prefs);
      expect(fresh.getItems().single.title, 'Yeni');
    });

    test('silme depodan da düşer', () async {
      final controller = build();
      await controller.add(item('w1', title: 'Birinci'));
      await controller.add(item('w2', title: 'İkinci'));

      final ok = await controller.remove('w1');

      expect(ok, isTrue);
      expect(controller.items.map((i) => i.id), ['w2']);
      expect(WishlistLocalDataSource(prefs).getItems().map((i) => i.id), ['w2']);
    });

    test('silme hatasında false döner', () async {
      SharedPreferences.setMockInitialValues({});
      final failingPrefs = _FailingPrefs(await SharedPreferences.getInstance());
      final controller = build(prefsOverride: failingPrefs);

      final ok = await controller.remove('yok');

      expect(ok, isFalse);
      expect(notifications, isNotEmpty);
    });
  });

  test('load depodaki kayıtları en yeni önce yükler', () async {
    final controller = build();
    await WishlistLocalDataSource(prefs).upsert(
      item('eski', addedAt: DateTime(2024, 1, 1)),
    );
    await WishlistLocalDataSource(prefs).upsert(
      item('yeni', addedAt: DateTime(2025, 1, 1)),
    );

    await controller.load();

    expect(controller.items.map((i) => i.id), ['yeni', 'eski']);
  });
}

/// Sadece test için: setString'i false dönen SharedPreferences sarmalayıcı.
class _FailingPrefs implements SharedPreferences {
  _FailingPrefs(this._inner);

  final SharedPreferences _inner;

  @override
  Future<bool> setString(String key, String value) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #getString
          ? _inner.getString(invocation.positionalArguments[0] as String)
          : super.noSuchMethod(invocation);
}

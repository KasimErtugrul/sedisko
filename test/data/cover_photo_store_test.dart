import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/services/cover_photo_store.dart';

void main() {
  late Directory tempRoot;
  late CoverPhotoStore store;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('cover_store_test');
    store = CoverPhotoStore(baseDir: () async => tempRoot);
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  group('CoverPhotoStore', () {
    test('saveFromTemp dosyayı covers klasörüne kopyalar', () async {
      final source = File('${tempRoot.path}${Platform.pathSeparator}tmp.jpg');
      await source.writeAsBytes([1, 2, 3, 4]);

      final saved = await store.saveFromTemp(source.path);
      final savedFile = File(saved);

      expect(savedFile.existsSync(), isTrue);
      expect(savedFile.readAsBytesSync(), [1, 2, 3, 4]);
      expect(saved, isNot(source.path));
      // Kalıcı klasör: <root>/covers
      final coversDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}covers',
      );
      expect(savedFile.parent.path, coversDir.path);
    });

    test('saveFromTemp uzantıyı korur, uzantısız kaynak .jpg olur', () async {
      final source = File('${tempRoot.path}${Platform.pathSeparator}raw');
      await source.writeAsBytes([1]);
      final saved = await store.saveFromTemp(source.path);
      expect(saved.endsWith('.jpg'), isTrue);

      final source2 = File('${tempRoot.path}${Platform.pathSeparator}r.png');
      await source2.writeAsBytes([1]);
      final saved2 = await store.saveFromTemp(source2.path);
      expect(saved2.endsWith('.png'), isTrue);
    });

    test('delete covers içindeki dosyayı siler', () async {
      final source = File('${tempRoot.path}${Platform.pathSeparator}a.png');
      await source.writeAsBytes([9]);
      final saved = await store.saveFromTemp(source.path);
      expect(File(saved).existsSync(), isTrue);

      await store.delete(saved);

      expect(File(saved).existsSync(), isFalse);
    });

    test('delete covers dışındaki yola dokunmaz', () async {
      final outside = File('${tempRoot.path}${Platform.pathSeparator}dis.jpg');
      await outside.writeAsBytes([1]);

      await store.delete(outside.path);

      expect(outside.existsSync(), isTrue);
    });

    test('delete null/boş/olmayan yolda patlamaz', () async {
      await store.delete(null);
      await store.delete('');
      await store.delete(
        '${tempRoot.path}${Platform.pathSeparator}covers'
        '${Platform.pathSeparator}yok.jpg',
      );
    });
  });
}

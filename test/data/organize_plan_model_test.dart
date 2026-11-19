import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/datasources/shelf_local_datasource.dart';
import 'package:kitaplik/data/models/organize_plan_model.dart';
import 'package:kitaplik/domain/services/organize_criterion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Taşıma planı modeli + kalıcılığı: JSON tur atlatma, bozuk kayıt
/// savunması, tamamlanan tur işaretlerinin kalıcılığı.
OrganizePlanModel samplePlan() {
  return OrganizePlanModel(
    criterion: OrganizeCriterion.author,
    createdAt: DateTime(2026, 1, 2, 9, 30),
    turs: [
      MoveTurModel(location: 'Alt kat', actions: [
        MoveActionModel(isPickup: true, shelf: 'Raf 1', moves: [
          const PlanMove(
            bookId: 'b1',
            title: 'Simyacı',
            fromShelf: 'Raf 1',
            toShelf: 'Raf 2',
          ),
        ]),
        MoveActionModel(isPickup: false, shelf: 'Raf 2', moves: [
          const PlanMove(
            bookId: 'b1',
            title: 'Simyacı',
            fromShelf: 'Raf 1',
            toShelf: 'Raf 2',
          ),
        ]),
      ]),
      MoveTurModel(location: 'Üst kat', actions: [
        MoveActionModel(isPickup: false, shelf: 'Raf 3', moves: [
          const PlanMove(
            bookId: 'b2',
            title: 'Dönüşüm',
            fromShelf: 'Raf 1',
            toShelf: 'Raf 3',
          ),
        ]),
      ]),
    ],
  );
}

void main() {
  group('OrganizePlanModel', () {
    test('json dönüşümü tur atlatır ve tamamlanmalar korunur', () {
      final plan = samplePlan().withCompleted([1]);
      final restored =
          OrganizePlanModel.tryFromJson(plan.toJson());
      expect(restored, isNotNull);
      expect(restored!.criterion, OrganizeCriterion.author);
      expect(restored.turs.length, 2);
      expect(restored.completedTurIndexes, [1]);
      expect(restored.totalMoveCount, 2);
      expect(restored.isComplete, isFalse);

      final done = restored.withCompleted([0, 1]);
      expect(done.isComplete, isTrue);
    });

    test('bilinmeyen kriter planı geçersiz kılar', () {
      expect(
        OrganizePlanModel.tryFromJson({
          'criterion': 'renge-gore',
          'turs': [],
        }),
        isNull,
      );
    });

    test('bozuk tur atlanır; tamamen bozuk plan null döner', () {
      final plan = samplePlan().toJson();
      // İlk turun emirlerini boz.
      ((plan['turs'] as List)[0] as Map)['actions'] = [
        {'kind': 'al', 'shelf': 'Raf 1', 'moves': []}, // boş: atlanır
      ];
      final restored = OrganizePlanModel.tryFromJson(plan);
      expect(restored, isNotNull);
      expect(restored!.turs.length, 1); // ikinci tur sağlam
    });

    test('kitap kimlikleri toplar (yeni gelenler için)', () {
      expect(samplePlan().bookIds, {'b1', 'b2'});
    });
  });

  group('ShelfLocalDataSource plan kalıcılığı', () {
    test('plan kaydedilir, güncellenir ve silinir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ShelfLocalDataSource(prefs);

      await store.savePlan(samplePlan());
      var loaded = store.getPlan();
      expect(loaded, isNotNull);
      expect(loaded!.turs.length, 2);

      await store.savePlan(loaded.withCompleted([0]));
      loaded = store.getPlan();
      expect(loaded!.completedTurIndexes, [0]);

      await store.savePlan(null);
      expect(store.getPlan(), isNull);
    });
  });
}

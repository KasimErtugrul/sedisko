import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/backup_model.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/shelf_model.dart';
import 'package:kitaplik/data/services/backup_service.dart';
import 'package:kitaplik/presentation/widgets/backup/import_mode_dialog.dart';

/// Keşke 40 (1.20.0): "Üzerine yaz" artık iki adımlı. İlk diyalog kipleri
/// anlatır; ikinci diyalog ("Bütün kitaplık değişecek") geri alınamaz
/// adımdan önce bir kez daha sorar. Onay verilmezse ilk diyalog açık
/// kalır; birleştir/vazgeç akışları hiç etkilenmez.
BackupEnvelope _envelope() => BackupEnvelope(
      exportedAt: DateTime(2026, 1, 1),
      appVersion: '1.20.0',
      books: [
        BookModel(id: 'b1', title: 'Dune', addedAt: DateTime(2026, 1, 1)),
        BookModel(id: 'b2', title: 'Sefiller', addedAt: DateTime(2026, 1, 1)),
      ],
      shelves: [ShelfModel(id: 's1', name: 'Salon', lengthCm: 100, order: 0)],
    );

BackupImportMode? lastResult;

Future<void> pumpOpener(WidgetTester tester) async {
  lastResult = null;
  await tester.pumpWidget(
    GetMaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () async {
              lastResult = await showDialog<BackupImportMode>(
                context: context,
                builder: (_) => BackupImportModeDialog(envelope: _envelope()),
              );
            },
            child: const Text('aç'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  testWidgets('üzerine yaz ikinci onay ister; onayla sonuç replace döner',
      (tester) async {
    await pumpOpener(tester);

    expect(find.text('Yedeği nasıl içe aktaralım?'), findsOneWidget);

    // İçerikteki açıklayıcı başlık da "Üzerine yaz" yazdığından düğmeyi
    // tipiyle daraltarak hedefle (TextButton yalnız aksiyon sırasında).
    await tester.tap(find.widgetWithText(TextButton, 'Üzerine yaz'));
    await tester.pumpAndSettle();

    // İkinci diyalog: geri alınamaz adım açıkça anlatılır.
    expect(find.text('Bütün kitaplık değişecek'), findsOneWidget);
    expect(find.textContaining('geri alınamaz'), findsOneWidget);
    expect(find.text('Evet, hepsini değiştir'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('overwrite-final-confirm')));
    await tester.pumpAndSettle();

    // Her iki diyalog da kapandı; kip replace olarak döndü.
    expect(find.text('Yedeği nasıl içe aktaralım?'), findsNothing);
    expect(lastResult, BackupImportMode.replace);
  });

  testWidgets('ikinci adımda vazgeçilirse kip seçimi diyaloğu açık kalır',
      (tester) async {
    await pumpOpener(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Üzerine yaz'));
    await tester.pumpAndSettle();

    // İlk diyalog hâlâ açık olduğundan "Vazgeç" iki diyaloğda da var;
    // yalnız İKİNCİ diyaloğunkine bas.
    final confirmDialog = find.ancestor(
      of: find.text('Bütün kitaplık değişecek'),
      matching: find.byType(AlertDialog),
    );
    await tester.tap(
      find.descendant(of: confirmDialog, matching: find.text('Vazgeç')),
    );
    await tester.pumpAndSettle();

    // İkinci diyalog kapandı; ilk diyalog hâlâ açık — karar zorlanmadı.
    expect(find.text('Bütün kitaplık değişecek'), findsNothing);
    expect(find.text('Yedeği nasıl içe aktaralım?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Birleştir'), findsOneWidget);
    expect(lastResult, isNull);
  });

  testWidgets('birleştir ikinci onaya gerek duymaz', (tester) async {
    await pumpOpener(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Birleştir'));
    await tester.pumpAndSettle();

    // Güvenli kip tek dokunuşla biter; ikinci diyalog hiç açılmaz.
    expect(find.text('Bütün kitaplık değişecek'), findsNothing);
    expect(find.text('Yedeği nasıl içe aktaralım?'), findsNothing);
    expect(lastResult, BackupImportMode.merge);
  });
}

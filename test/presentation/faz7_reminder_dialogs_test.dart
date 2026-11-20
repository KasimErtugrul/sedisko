import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/models/borrowed_book_model.dart';
import 'package:kitaplik/presentation/widgets/borrowed_dialog.dart';
import 'package:kitaplik/presentation/widgets/lend_dialog.dart';
import 'package:kitaplik/presentation/widgets/reminder_date_row.dart';

/// Keşke 34/35 (1.26.0): ödünç diyaloglarının hatırlatma günü satırı.
///
/// Hasan'ın notlarındaki iki senaryo: '+1 hafta' çipiyle tek dokunuşta
/// tarih seçmek ve seçilen günü kaldırmak. Çipe dokunulmayan kayıt
/// hatırlatmasız yaşar — eski davranış aynen korunur.
void main() {
  setUp(() {
    Get.testMode = true;
  });

  Future<DateTime?> pumpLendAndSubmit(
    WidgetTester tester, {
    void Function()? beforeSubmit,
  }) async {
    DateTime? due;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showLendDialog(context);
                if (result != null) due = result.$3;
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('lend-person-field')),
      'Ayşe',
    );
    beforeSubmit?.call();

    await tester.tap(find.byKey(const ValueKey('lend-submit-button')));
    await tester.pumpAndSettle();
    return due;
  }

  testWidgets('ödünç ver diyaloğu hatırlatmasız açılır ve null döner',
      (tester) async {
    final due = await pumpLendAndSubmit(tester);
    expect(due, isNull);
  });

  testWidgets('+1 hafta çipi dokunulunca sonuç yedi gün sonrası olur',
      (tester) async {
    DateTime? due;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showLendDialog(context);
                if (result != null) due = result.$3;
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('lend-person-field')),
      'Ayşe',
    );

    await tester.tap(find.byKey(const ValueKey('reminder-chip-week')));
    await tester.pumpAndSettle();

    // Seçili gün görünür olur ve temizleme düğmesi çıkar.
    expect(find.textContaining('Hatırlatma:'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-clear')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lend-submit-button')));
    await tester.pumpAndSettle();

    expect(due, isNotNull);
    final now = DateTime.now();
    final expectedDay = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 7, hours: 9));
    // Akşam seçimlerinde ertesi sabaha kayabilir; iki olası gün de kabul.
    final expectedNextDay = expectedDay.add(const Duration(days: 1));
    bool isSameDay(DateTime d1, DateTime d2) =>
        d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
    final ok = isSameDay(due!, expectedDay) || isSameDay(due!, expectedNextDay);
    expect(ok, isTrue);
    expect(due!.hour, 9);
  });

  testWidgets('hatırlatma günü temizlenince sonuç yeniden null olur',
      (tester) async {
    DateTime? due;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showLendDialog(context);
                if (result != null) due = result.$3;
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('lend-person-field')),
      'Ayşe',
    );
    await tester.tap(find.byKey(const ValueKey('reminder-chip-week')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-clear')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hatırlatma:'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('lend-submit-button')));
    await tester.pumpAndSettle();
    expect(due, isNull);
  });

  testWidgets('gün→hatırlatma dönüşümü sabah dokuzu hedefler; geçmişe',
      (tester) async {
    final now = DateTime(2026, 11, 20, 14);
    final past = ReminderDateRow.dayToReminder(
      DateTime(2026, 11, 20),
      now: now,
    );
    // Aynı gün 09:00 geçmiş kaldı: ertesi sabaha kayar.
    expect(past, DateTime(2026, 11, 21, 9));

    final future = ReminderDateRow.dayToReminder(
      DateTime(2026, 11, 27),
      now: now,
    );
    expect(future, DateTime(2026, 11, 27, 9));
  });

  testWidgets('ödünç al diyaloğu hatırlatma satırı taşır ve günü döndürür',
      (tester) async {
    DateTime? remindAt;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showBorrowedDialog(context);
                if (result != null) remindAt = result.$5;
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('borrowed-title-field')),
      'Beyaz Kale',
    );
    await tester.enterText(
      find.byKey(const ValueKey('borrowed-owner-field')),
      'Komşu Ahmet',
    );

    // Satır başlığı keşke 35 dilini taşır.
    expect(
      find.text('Sahibine geri ver hatırlatması (isteğe bağlı)'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('reminder-chip-2week')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('borrowed-submit-button')));
    await tester.pumpAndSettle();

    expect(remindAt, isNotNull);
    expect(remindAt!.hour, 9);
  });

  testWidgets('ödünç düzenle diyaloğu kayıtlı günü öndoldurur', (tester) async {
    DateTime? remindAt;
    final existing = BorrowedBookModel(
      id: 'bo1',
      title: 'Yaban',
      owner: 'Halit',
      borrowedAt: DateTime(2026, 11, 1),
      remindAt: DateTime(2026, 11, 21, 9),
    );

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result =
                    await showBorrowedDialog(context, existing: existing);
                if (result != null) remindAt = result.$5;
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hatırlatma:'), findsOneWidget);
    expect(find.text('Ödünç düzenle'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('borrowed-submit-button')));
    await tester.pumpAndSettle();
    expect(remindAt, DateTime(2026, 11, 21, 9));
  });
}

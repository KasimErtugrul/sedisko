import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/reading_log_entry.dart';
import 'package:kitaplik/presentation/widgets/reading_stats_panel.dart';

Widget host(BookModel book) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReadingStatsPanel(book: book),
        ),
      ),
    );

BookModel bookWithLog() {
  final now = DateTime.now();
  return BookModel(
    id: 'b1',
    title: 'Test Kitabı',
    pageCount: 300,
    status: ReadingStatus.reading,
    currentPage: 95,
    addedAt: now.subtract(const Duration(days: 10)),
    readingLog: [
      ReadingLogEntry(at: now.subtract(const Duration(days: 9)), page: 0),
      ReadingLogEntry(at: now.subtract(const Duration(days: 3)), page: 50),
      ReadingLogEntry(at: now.subtract(const Duration(hours: 2)), page: 95),
    ],
  );
}

void main() {
  testWidgets('Günlük boşken rehber metni gösterir', (tester) async {
    final book = BookModel(
      id: 'b1',
      title: 'Yeni Kitap',
      addedAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(host(book));

    expect(find.text('Okuma İstatistikleri'), findsOneWidget);
    expect(find.textContaining('burada birikir'), findsOneWidget);
    // Grafik ve kutular gizli kalmalı.
    expect(find.byKey(const ValueKey('daily-bar-0')), findsNothing);
  });

  testWidgets('İstatistik kutuları doğru değerleri gösterir', (tester) async {
    await tester.pumpWidget(host(bookWithLog()));

    // Toplam okunan ve son 7 gün: 95.
    expect(find.text('95'), findsNWidgets(2));
    // Günlük ortalama: 95 sayfa / 10 takvim günü = 9.5.
    expect(find.text('9.5'), findsOneWidget);
    // En verimli gün: 50.
    expect(find.text('50'), findsOneWidget);
    expect(find.text('Okunan sayfa'), findsOneWidget);
    expect(find.text('Günlük ortalama'), findsOneWidget);
    expect(find.text('Son 7 gün'), findsOneWidget);
    expect(find.text('En verimli gün'), findsOneWidget);
  });

  testWidgets('Mini grafik 14 günlük bar üretir', (tester) async {
    await tester.pumpWidget(host(bookWithLog()));

    for (var i = 0; i < 14; i++) {
      expect(find.byKey(ValueKey('daily-bar-$i')), findsOneWidget);
    }
  });

  testWidgets('Son kayıtlar ilerleme miktarıyla listelenir', (tester) async {
    await tester.pumpWidget(host(bookWithLog()));

    expect(find.text('Son kayıtlar'), findsOneWidget);
    expect(find.text('Sayfa 95'), findsOneWidget);
    expect(find.text('Sayfa 50'), findsOneWidget);
    expect(find.text('+45 sayfa'), findsOneWidget);
    expect(find.text('+50 sayfa'), findsOneWidget);
    // Referans kaydı için ilerleme gösterilmez.
    expect(find.text('+0 sayfa'), findsNothing);
  });
}

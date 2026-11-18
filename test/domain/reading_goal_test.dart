import 'package:flutter_test/flutter_test.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/domain/services/reading_goal.dart';

/// Bitirme hedefi hesapları: takvim günü farkı, günlük sayfa planı,
/// gecikme ve bitmiş kitapta hedefe göre sonuç.
///
/// Tüm testler sabit saat kullanır; gün karşılaştırmaları takvim günü
/// bazlı olduğundan testin çalıştırıldığı saat sonucu değiştirmez
/// (gece yarısı sınırı regresyonu dahil).
void main() {
  final now = DateTime(2026, 6, 15, 14, 30);

  BookModel book({
    DateTime? target,
    ReadingStatus status = ReadingStatus.reading,
    int pageCount = 300,
    int currentPage = 100,
    DateTime? finishedAt,
  }) {
    return BookModel(
      id: 'g1',
      title: 'Hedefli kitap',
      addedAt: DateTime(2026, 6, 1),
      status: status,
      pageCount: pageCount,
      currentPage: currentPage,
      finishedAt: finishedAt,
      targetFinishDate: target,
    );
  }

  group('ReadingGoal.daysLeft', () {
    test('hedef bugünse 0 döner', () {
      final today = DateTime(2026, 6, 15, 9, 0);
      expect(ReadingGoal.daysLeft(today, now), 0);
    });

    test('gelecek tarih pozitif gün verir', () {
      expect(ReadingGoal.daysLeft(DateTime(2026, 6, 20), now), 5);
    });

    test('geçmiş tarih negatif gün verir', () {
      expect(ReadingGoal.daysLeft(DateTime(2026, 6, 10), now), -5);
    });

    test('saat farkı sonucu değiştirmez (gece yarısı sınırı)', () {
      // Hedef 16 Haziran 00:10, şimdi 15 Haziran 23:50. Ham fark hesapla-
      // nsa 20 dakikalık bir süre çıkar; takvim günü karşılaştırması
      // doğruca 1 verir ve gece yarısı sınırı sürprizi olmaz.
      final target = DateTime(2026, 6, 16, 0, 10);
      final lateNight = DateTime(2026, 6, 15, 23, 50);
      expect(ReadingGoal.daysLeft(target, lateNight), 1);
    });
  });

  group('ReadingGoal.pagesPerDay', () {
    test('kalan sayfayı kalan güne böler ve yukarı yuvarlar', () {
      // 300-100 = 200 sayfa / 5 gün = 40.0 → 40
      final b = book(target: DateTime(2026, 6, 20));
      expect(ReadingGoal.pagesPerDay(b, now), 40);
    });

    test('tam bölünmeyense bir üst güne yuvarlar', () {
      // 200 sayfa / 3 gün = 66.66 → 67
      final b = book(target: DateTime(2026, 6, 18));
      expect(ReadingGoal.pagesPerDay(b, now), 67);
    });

    test('hedef yoksa null döner', () {
      expect(ReadingGoal.pagesPerDay(book(target: null), now), isNull);
    });

    test('kitap bitmişse null döner', () {
      final b = book(
        target: DateTime(2026, 6, 20),
        status: ReadingStatus.finished,
      );
      expect(ReadingGoal.pagesPerDay(b, now), isNull);
    });

    test('sayfa sayısı bilinmiyorsa null döner', () {
      final b = book(target: DateTime(2026, 6, 20), pageCount: 0);
      expect(ReadingGoal.pagesPerDay(b, now), isNull);
    });

    test('hedef sayfaya ulaşılmışsa null döner', () {
      final b = book(target: DateTime(2026, 6, 20), currentPage: 300);
      expect(ReadingGoal.pagesPerDay(b, now), isNull);
    });

    test('hedef tarihi geçmişse null döner (plan anlamını yitirir)', () {
      final b = book(target: DateTime(2026, 6, 10));
      expect(ReadingGoal.pagesPerDay(b, now), isNull);
    });
  });

  group('ReadingGoal.isOverdue', () {
    test('hedef geçmiş ve bitmemişse true', () {
      expect(
        ReadingGoal.isOverdue(book(target: DateTime(2026, 6, 10)), now),
        isTrue,
      );
    });

    test('hedef bugünse henüz gecikme yok', () {
      expect(
        ReadingGoal.isOverdue(book(target: DateTime(2026, 6, 15)), now),
        isFalse,
      );
    });

    test('hedef gelecekteyse false', () {
      expect(
        ReadingGoal.isOverdue(book(target: DateTime(2026, 7, 1)), now),
        isFalse,
      );
    });

    test('hedef geçse bile bitmiş kitap gecikmiş sayılmaz', () {
      final b = book(
        target: DateTime(2026, 6, 10),
        status: ReadingStatus.finished,
        finishedAt: DateTime(2026, 6, 20),
      );
      expect(ReadingGoal.isOverdue(b, now), isFalse);
    });

    test('hedef yoksa false', () {
      expect(ReadingGoal.isOverdue(book(target: null), now), isFalse);
    });
  });

  group('ReadingGoal.finishedAgainstTarget', () {
    test('hedefinden önce biten kitapta pozitif gün döner', () {
      final b = book(
        target: DateTime(2026, 6, 20),
        status: ReadingStatus.finished,
        finishedAt: DateTime(2026, 6, 17),
      );
      expect(ReadingGoal.finishedAgainstTarget(b), 3);
    });

    test('hedefi aşan kitapta negatif gün döner', () {
      final b = book(
        target: DateTime(2026, 6, 10),
        status: ReadingStatus.finished,
        finishedAt: DateTime(2026, 6, 17),
      );
      expect(ReadingGoal.finishedAgainstTarget(b), -7);
    });

    test('tam gününde bitiş 0 döner', () {
      final b = book(
        target: DateTime(2026, 6, 17),
        status: ReadingStatus.finished,
        finishedAt: DateTime(2026, 6, 17, 22, 0),
      );
      expect(ReadingGoal.finishedAgainstTarget(b), 0);
    });

    test('hedef yoksa null döner', () {
      expect(
        ReadingGoal.finishedAgainstTarget(book(target: null)),
        isNull,
      );
    });

    test('bitmemiş kitapta null döner', () {
      expect(
        ReadingGoal.finishedAgainstTarget(book(target: DateTime(2026, 6, 20))),
        isNull,
      );
    });
  });
}

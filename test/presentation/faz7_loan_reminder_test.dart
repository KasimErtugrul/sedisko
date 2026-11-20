import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kitaplik/data/datasources/loan_local_datasource.dart';
import 'package:kitaplik/data/models/book_model.dart';
import 'package:kitaplik/data/models/borrowed_book_model.dart';
import 'package:kitaplik/data/models/loan_model.dart';
import 'package:kitaplik/data/services/reading_reminder_service.dart';
import 'package:kitaplik/presentation/controllers/loan_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keşke 34/35 (1.26.0): ödünç hatırlatmalarının zamanlama akışı.
///
/// İki yön test edilir: kayıt yazıldığında TEK SEFERLİK bildirim kurulur
/// (verilen ödünçte 'iade günü', alınan ödünçte 'geri verme günü'); kayıt
/// geri alınınca/silinince/günü temizlenince planlı bildirim iptal edilir.
/// Zamanlayıcı verilmezse (izole kurulumlar) akış sessizce atlanır: kayıt
/// yazma davranışı hiç değişmez.
class _RecordingScheduler implements ReminderScheduler {
  final List<({int id, String title, String body, DateTime at})> onceCalls =
      [];
  final List<int> cancelCalls = [];
  bool result = true;

  @override
  Future<bool> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async => result;

  @override
  Future<bool> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    onceCalls.add((id: id, title: title, body: body, at: at));
    return result;
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls.add(id);
  }
}

void main() {
  late LoanLocalDataSource store;
  late List<String> notifications;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LoanLocalDataSource(prefs);
    notifications = [];
  });

  tearDown(() {
    Get.reset();
  });

  LoanController buildController({
    ReminderScheduler? scheduler,
    LoanLocalDataSource? customStore,
  }) {
    return LoanController(
      store: customStore ?? store,
      reminderScheduler: scheduler,
      onNotify: (title, message) => notifications.add('$title|$message'),
    );
  }

  BookModel book(String id, {String title = 'Dune'}) => BookModel(
        id: id,
        title: title,
        addedAt: DateTime(2026, 1, 1),
      );

  DateTime futureDay([int days = 7]) =>
      DateTime.now().add(Duration(days: days));

  test('dueAt ile verilen ödünç iade günü bildirimi kurar', () async {
    final scheduler = _RecordingScheduler();
    final controller = buildController(scheduler: scheduler);
    final due = futureDay();

    final ok = await controller.lendBook(book('b1'), 'Ayşe', dueAt: due);

    expect(ok, isTrue);
    expect(scheduler.onceCalls, hasLength(1));
    final call = scheduler.onceCalls.single;
    expect(call.title, 'İade günü');
    expect(
      call.body,
      '"Dune" kitabını bugün Ayşe kişiden geri isteyebilirsin.',
    );
    expect(call.id, LoanController.reminderId(controller.loans.single.id));
    // Depoya da yazıldı: gün kaybolmaz.
    expect(store.getLoans().single.dueAt, isNotNull);
  });

  test('hatırlatmasız ödünç hiçbir kurulum yapmaz (eski davranış)', () async {
    final scheduler = _RecordingScheduler();
    final controller = buildController(scheduler: scheduler);

    final ok = await controller.lendBook(book('b1'), 'Ayşe');

    expect(ok, isTrue);
    expect(scheduler.onceCalls, isEmpty);
    expect(scheduler.cancelCalls, isEmpty);
    expect(store.getLoans().single.dueAt, isNull);
  });

  test('geçmiş gün sessizce "yok" olur; kurulum yapılmaz', () async {
    final scheduler = _RecordingScheduler();
    final controller = buildController(scheduler: scheduler);

    final ok = await controller.lendBook(
      book('b1'),
      'Ayşe',
      dueAt: DateTime(2026, 1, 1, 9),
    );

    expect(ok, isTrue);
    expect(scheduler.onceCalls, isEmpty);
    expect(store.getLoans().single.dueAt, isNull);
  });

  test('kurulum başarısızsa kayıt yaşar ve kullanıcı haberdar edilir',
      () async {
    final scheduler = _RecordingScheduler()..result = false;
    final controller = buildController(scheduler: scheduler);

    final ok = await controller.lendBook(book('b1'), 'Ayşe', dueAt: futureDay());

    expect(ok, isTrue); // kayıt yazıldı
    expect(scheduler.onceCalls, hasLength(1));
    expect(notifications.single, contains('Hatırlatma kurulamadı'));
    expect(notifications.single, contains('bildirim izni'));
  });

  test('kitap geri alınınca iade hatırlatması iptal edilir', () async {
    final scheduler = _RecordingScheduler();
    final controller = buildController(scheduler: scheduler);

    await controller.lendBook(book('b1'), 'Ayşe', dueAt: futureDay());
    expect(scheduler.onceCalls, hasLength(1));

    final cancelledBefore = scheduler.cancelCalls.length;
    await controller.markReturned(controller.loans.single.id);
    expect(scheduler.cancelCalls.length, cancelledBefore + 1);
    expect(
      scheduler.cancelCalls.last,
      LoanController.reminderId(controller.loans.single.id),
    );
  });

  test('ödünç kaydı silinince hatırlatması iptal edilir', () async {
    final scheduler = _RecordingScheduler();
    final controller = buildController(scheduler: scheduler);

    await controller.lendBook(book('b1'), 'Ayşe', dueAt: futureDay());
    final id = controller.loans.single.id;

    await controller.removeLoan(id);
    expect(scheduler.cancelCalls.last, LoanController.reminderId(id));
  });

  test("remindAt ile alıntı kaydı 'geri verme günü' bildirimi kurar",
      () async {
    final scheduler = _RecordingScheduler();
    final controller = buildController(scheduler: scheduler);

    final ok = await controller.addBorrowed(
      title: 'Beyaz Kale',
      owner: 'Komşu Ahmet',
      remindAt: futureDay(14),
    );

    expect(ok, isTrue);
    expect(scheduler.onceCalls, hasLength(1));
    final call = scheduler.onceCalls.single;
    expect(call.title, 'Geri verme günü');
    expect(
      call.body,
      '"Beyaz Kale" kitabını bugün Komşu Ahmet kişiye geri verebilirsin.',
    );
    expect(call.id, LoanController.reminderId(controller.borrowed.single.id));
  });

  test('alıntı düzenlemede gün temizlenirse alarm iptal edilir', () async {
    final scheduler = _RecordingScheduler();
    final controller = buildController(scheduler: scheduler);

    await controller.addBorrowed(
      title: 'Beyaz Kale',
      owner: 'Komşu Ahmet',
      remindAt: futureDay(14),
    );
    final item = controller.borrowed.single;

    await controller.updateBorrowed(item.copyWith(remindAt: null));
    expect(scheduler.cancelCalls.last, LoanController.reminderId(item.id));
  });

  test('alıntı geri verildi işaretlenince hatırlatma iptal edilir', () async {
    final scheduler = _RecordingScheduler();
    final controller = buildController(scheduler: scheduler);

    await controller.addBorrowed(
      title: 'Şeker Portakalı',
      owner: 'Elif',
      remindAt: futureDay(),
    );

    await controller.markBorrowedReturned(controller.borrowed.single.id);
    expect(
      scheduler.cancelCalls.last,
      LoanController.reminderId(controller.borrowed.single.id),
    );
  });

  test('açılışta gelecek hatırlatmalar yeniden kurulur (reboot kurtarması)',
      () async {
    // Depoya eski çalışmadan kalan iki kayıt bırak: biri gelecek tarihli,
    // biri hatırlatmasız.
    await store.upsertLoan(LoanModel(
      id: 'old1',
      bookId: 'b1',
      bookTitle: 'Dune',
      person: 'Ayşe',
      lentAt: DateTime(2026, 11, 1),
      dueAt: futureDay(3),
    ));
    await store.upsertBorrowed(BorrowedBookModel(
      id: 'old2',
      title: 'Yaban',
      owner: 'Halit',
      borrowedAt: DateTime(2026, 11, 2),
    ));

    final scheduler = _RecordingScheduler();
    final controller = buildController(scheduler: scheduler);
    await controller.load();

    expect(scheduler.onceCalls, hasLength(1));
    expect(scheduler.onceCalls.single.title, 'İade günü');
    expect(scheduler.onceCalls.single.id, LoanController.reminderId('old1'));
    // Hatırlatmasız kaydın artık alarmı yoktur.
    expect(scheduler.cancelCalls, contains(LoanController.reminderId('old2')));
  });

  test('zamanlayıcı verilmezse akış atlanır; kayıt yazma hiç değişmez',
      () async {
    final controller = buildController();

    final ok = await controller.lendBook(book('b1'), 'Ayşe', dueAt: futureDay());

    expect(ok, isTrue);
    expect(controller.loans.single.dueAt, isNotNull);
    expect(notifications, isEmpty);
  });
}

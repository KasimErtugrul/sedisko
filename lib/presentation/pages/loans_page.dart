import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/date_formatter.dart';
import '../../data/models/loan_model.dart';
import '../controllers/loan_controller.dart';
import '../utils/app_navigation.dart';

/// 'Ödünç verilenler' sayfası (1.18.0): kitaplıkta verdiğimiz kitapların
/// tüm geçmişi.
///
/// İki bölüm: 'Sürüyor' ([LoanController.activeLoans]) ve 'Geri alınanlar'
/// ([LoanController.returnedLoans]). Aktif kartta 'Geri alındı' düğmesi;
/// basılı tutunca kayıt silme onayı açılır. Kitap detayındaki
/// "Ödünç ver" aksiyonuyla yeni kayıt açılır.
class LoansPage extends StatelessWidget {
  const LoansPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoanController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ödünç verilenler')),
      body: Obx(() {
        final active = controller.activeLoans;
        final returned = controller.returnedLoans;
        if (active.isEmpty && returned.isEmpty) {
          return const _EmptyView();
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          children: [
            if (active.isNotEmpty) ...[
              _SectionHeader(title: 'Sürüyor', count: active.length),
              for (final loan in active) _LoanCard(loan: loan, isActive: true),
            ],
            if (returned.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SectionHeader(title: 'Geri alınanlar', count: returned.length),
              for (final loan in returned) _LoanCard(loan: loan, isActive: false),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(
                'Kitap detayındaki "Ödünç ver" aksiyonuyla kitap takibi yapılır.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan, required this.isActive});

  final LoanModel loan;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Baş harf olduğu gibi kullanılır: Türkçe I/İ dönüşümü yanlış harf
    // üretebilir ('i'.toUpperCase() → 'I'), bu yüzden dönüştürülmez.
    final initial = loan.person.isEmpty ? '?' : loan.person.characters.first;

    final subtitle = isActive
        ? '${loan.person} • verildi: ${formatDate(loan.lentAt)}'
        : '${loan.person} • geri alındı: ${formatDate(loan.returnedAt)}';

    return Card(
      key: ValueKey('loan-card-${loan.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(
            initial,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          loan.bookTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (loan.note != null)
              Text(
                loan.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.outline,
                ),
              ),
          ],
        ),
        isThreeLine: loan.note != null,
        trailing: isActive
            ? TextButton(
                onPressed: _markReturned,
                child: const Text('Geri alındı'),
              )
            : const Icon(Icons.check_circle_outline),
        onLongPress: () => _confirmDelete(context),
      ),
    );
  }

  void _markReturned() async {
    final ok = await Get.find<LoanController>().markReturned(loan.id);
    if (ok) {
      Get.snackbar(
        'Geri alındı',
        '"${loan.bookTitle}" ${loan.person} kişisinden iade edildi.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Kayıt silinsin mi?'),
        content: Text(
          '"${loan.bookTitle}" — ${loan.person} ödünç kaydı kalıcı olarak '
          'silinecek. Kitabın kendisi kitaplıkta kalır.',
        ),
        actions: [
          TextButton(
            onPressed: () => AppNav.pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () async {
              AppNav.pop(); // diyalog
              await Get.find<LoanController>().removeLoan(loan.id);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.book_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Henüz ödünç verilen kitap yok.\n'
              'Kitap detayındaki "Ödünç ver" aksiyonunu kullanabilirsin.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

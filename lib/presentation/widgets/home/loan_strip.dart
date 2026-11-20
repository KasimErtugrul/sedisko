import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/loan_model.dart';

/// "Ödünç verilenler" yatay şeridi (1.18.0).
///
/// Her kart: kişi baş harf avatarı + kişi adı + kitap adı (iki satıra
/// kadar) + veriliş tarihi. Ana sayfa bölüm gövdesi olarak kullanılır;
/// dokunuş [onTapLoan] ile çağırana iletilir (hedef sayfayı bağlayan
/// entegratör belirler). Şerit ana akışın dikey ListView'ı içinde tek
/// satır kaplar ve yatayda bağımsız kayar.
class LoanStrip extends StatelessWidget {
  const LoanStrip({super.key, required this.loans, this.onTapLoan});

  final List<LoanModel> loans;

  final void Function(LoanModel loan)? onTapLoan;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: loans.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final loan = loans[index];
          return _LoanCard(
            key: ValueKey('loan-strip-${loan.id}'),
            loan: loan,
            onTap: () => onTapLoan?.call(loan),
          );
        },
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({super.key, required this.loan, required this.onTap});

  final LoanModel loan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Baş harf olduğu gibi kullanılır: Türkçe I/İ dönüşümü yanlış harf
    // üretebilir ('i'.toUpperCase() → 'I'), bu yüzden dönüştürülmez.
    final initial = loan.person.isEmpty ? '?' : loan.person.characters.first;

    return SizedBox(
      width: 148,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: Text(
                        initial,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        loan.person,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    loan.bookTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  'verildi: ${formatDate(loan.lentAt)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

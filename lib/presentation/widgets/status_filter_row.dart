import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/book_model.dart';
import '../controllers/library_controller.dart';

/// Okuma durumu filtre çipleri; arama sonuçları ve raf sayfası paylaşır.
class StatusFilterRow extends GetView<LibraryController> {
  const StatusFilterRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Obx(() {
        final selected = controller.statusFilter.value;
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Hepsi'),
                selected: selected == null,
                onSelected: (_) => controller.statusFilter.value = null,
              ),
            ),
            for (final s in ReadingStatus.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.label),
                  selected: selected == s,
                  onSelected: (_) => controller.statusFilter.value = s,
                ),
              ),
          ],
        );
      }),
    );
  }
}

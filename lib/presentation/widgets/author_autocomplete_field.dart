import 'package:flutter/material.dart';

import '../../core/utils/text_normalizer.dart';

/// Yazar alanı için daha önce girilmiş yazarlardan öneri getiren
/// otomatik tamamlama alanı (1.16.0, kullanıcı isteği).
///
/// Kullanıcı yazar yazmaya başlayınca kitaplıkta daha önce geçen
/// yazarlar küçük bir listede çıkar; seçilen ad alana yazılır ve kullanıcı
/// zaman kazanır. Alan ÇOKLU yazar kabul eder (virgülle ayrılır), bu
/// yüzden öneri yalnız SON virgülden sonraki aktif yazım için üretilir:
///
/// - "Orhan Pamuk, ah" → öneriler "ah" ile eşleşen yazarlar
/// - "Orhan Pamuk, "   → aktif yazım boş; öneri yok (liste kirlenmesin)
///
/// Eşleşme [TextNormalizer.searchKey] ile Türkçe katlanarak yapılır:
/// "ahm" → "Ahmet Ümit", "ahmet ümit" büyük/küçük fark etmez.
/// Sıralama: baştan eşleşenler önce, sonra içerenler; her grupta
/// kitaplık sırası korunur. En fazla [maxOptions] öneri gösterilir.
///
/// [RawAutocomplete] kullanır: alan [TextFormField] kalır (mevcut form
/// düzeni, dekor ve denetleyici korunur); öneri katmanı yalnız öneri
/// olduğunda açılır.
///
/// Seçim anında alanın eski metni korunsun diye seçim metni
/// [displayStringForOption] ile üretilir: RawAutocomplete alanı bu
/// dizenin üzerine yazmadan ÖNCE bu çağrıyı yapar, yani aktif yazımın
/// öncesindeki yazarlar ("Orhan Pamuk, ") hâlâ alanın içindeyken
/// birleştirme yapılabilir. Seçilen ad virgül eklenerek yazılır ki ikinci
/// yazar hemen yazılabilsin; imleç satır sonunda kalır.
class AuthorAutocompleteField extends StatefulWidget {
  const AuthorAutocompleteField({
    super.key,
    required this.controller,
    required this.options,
    required this.decoration,
    this.maxOptions = 6,
  });

  /// Formun yazar alanı denetleyicisi; seçim bu denetleyiciye yazılır.
  final TextEditingController controller;

  /// Öneri havuzu: kitaplıkta daha önce geçmiş yazar adları (görünen ad).
  final List<String> options;

  final InputDecoration decoration;

  /// Açılan listede gösterilecek en fazla öneri sayısı.
  final int maxOptions;

  @override
  State<AuthorAutocompleteField> createState() =>
      _AuthorAutocompleteFieldState();
}

class _AuthorAutocompleteFieldState extends State<AuthorAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Aktif yazım: son virgülden sonraki bölüm (tek yazar görünümünde tümü).
  String _activeSegment(String text) {
    final lastComma = text.lastIndexOf(',');
    final segment = lastComma >= 0 ? text.substring(lastComma + 1) : text;
    return segment.trim();
  }

  /// Seçim metni: alanın MEVCUT (henüz üzerine yazılmamış) metnindeki
  /// önceki yazarları koruyarak [selection]'ı birleştirir ve sonuna
  /// virgül ekler. RawAutocomplete alanı bu dizinin üzerine yazar;
  /// imleç dizinin sonuna konur. Sonraki yazar için dizenin sonu
  /// ', ' ile biter.
  String _mergedSelectionText(String selection) {
    final text = widget.controller.text;
    final lastComma = text.lastIndexOf(',');
    final prefix = lastComma >= 0 ? text.substring(0, lastComma + 1) : '';
    final trimmedPrefix = prefix.trim();
    return trimmedPrefix.isEmpty
        ? '$selection, '
        : '$trimmedPrefix $selection, ';
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) => _optionsFor(value.text),
      // Seçim metni buradan üretilir: RawAutocomplete alanı bu dizenin
      // üzerine yazmadan ÖNCE çağırır; böylece "Önceki Yazar, " öneki
      // korunur (bkz. sınıf belgesi).
      displayStringForOption: _mergedSelectionText,
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 220,
              maxWidth: 420,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options.elementAt(index);
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline, size: 20),
                  title: Text(option),
                  onTap: () => onSelected(option),
                );
              },
            ),
          ),
        ),
      ),
      fieldViewBuilder:
          (context, textController, focusNode, onFieldSubmitted) =>
              TextFormField(
        controller: textController,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        decoration: widget.decoration,
        onFieldSubmitted: (_) => onFieldSubmitted(),
      ),
    );
  }

  /// [text] içindeki aktif yazımla eşleşen yazarlar; eşleşme yoksa boş
  /// liste (RawAutocomplete katmanı açmaz).
  List<String> _optionsFor(String text) {
    final active = _activeSegment(text);
    if (active.isEmpty) return const <String>[];

    final typed = TextNormalizer.searchKey(active);
    final starts = <String>[];
    final contains = <String>[];
    for (final option in widget.options) {
      final key = TextNormalizer.searchKey(option);
      if (key == typed) continue; // zaten tam yazılmış; öneriye gerek yok
      if (key.startsWith(typed)) {
        starts.add(option);
      } else if (key.contains(typed)) {
        contains.add(option);
      }
    }
    return [...starts, ...contains].take(widget.maxOptions).toList();
  }
}

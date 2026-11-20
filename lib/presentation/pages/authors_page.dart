import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/text_normalizer.dart';
import '../controllers/library_controller.dart';
import '../routes/app_routes.dart';
import '../utils/haber_seridi.dart';
import '../routes/route_args.dart';
import '../widgets/author_rename_dialog.dart';

/// 'Yazarlar' sekmesi: kitaplıktaki yazarların grid görünümü.
///
/// Kullanıcı isteği: "yazarlar diye bir buton olsa, basınca yazarların
/// isimlerini gridview ile görebilsek, yazar adına basınca kitaplarını
/// görebilsek." Buradan:
/// - Karta dokununca yazarın kitapları [Routes.shelf] üzerinde açılır
///   (authorKey filtresiyle; kitap detayındaki yazar dokunuşuyla aynı sayfa).
/// - Kartın köşesindeki kalem simgesi (1.20.0 — keşke 19) yazar adı
///   değiştirme diyaloğu açar: Open Library'nin sadeleştirdiği yazımlar
///   ("Kasim" ↔ "Kasım") tek isimde birleştirilir. Basılı tutma yolu
///   da aynı işi yapmaya devam eder.
///
/// Keşke 18 (1.26.0): sayfa kendi arama kutusunu taşır — "Yazar sayısı
/// artınca kaydırarak aramak eziyet oldu." Arama aksan/büyük-küçük
/// katlamasıyla ([TextNormalizer.searchKey]) yapılır; ana sayfanın kitap
/// aramasıyla aynı kurallar. Boş sorguda liste eskisi gibidir.
///
/// Yazarlar, aksan/büyük-küçük farkı katlanarak tek kartta toplanır
/// ([LibraryController.authors]); kartta kitap sayısı gösterilir.
class AuthorsPage extends StatefulWidget {
  const AuthorsPage({super.key});

  @override
  State<AuthorsPage> createState() => _AuthorsPageState();
}

class _AuthorsPageState extends State<AuthorsPage> {
  LibraryController get controller => Get.find<LibraryController>();

  final _queryCtrl = TextEditingController();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yazarlar')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.books.isEmpty) {
          return const _MessageView(
            icon: Icons.library_books_outlined,
            message: 'Kitaplığın boş.\nİlk kitabını ana sayfadan ekle.',
          );
        }
        final query = TextNormalizer.searchKey(_queryCtrl.text);
        final authors = query.isEmpty
            ? controller.authors
            : [
                for (final author in controller.authors)
                  if (TextNormalizer.searchKey(author).contains(query)) author,
              ];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                key: const Key('authors-search-field'),
                controller: _queryCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Yazar ara',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _queryCtrl.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Aramayı temizle',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _queryCtrl.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: authors.isEmpty
                  ? _MessageView(
                      icon: Icons.person_search_outlined,
                      message: query.isEmpty
                          ? 'Kitaplıkta yazar bilgisi yok.'
                          : 'Aramana uyan yazar yok.',
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        // Dar ekranda (360-400 dp) kart yüksekliği baş harf + iki
                        // satır ad + kitap sayısına yetmeli; 0.9'da 13 px taşma
                        // olurdu (400 dp test yüzeyinde doğrulandı).
                        childAspectRatio: 0.8,
                      ),
                      itemCount: authors.length,
                      itemBuilder: (context, index) {
                        final author = authors[index];
                        final key = TextNormalizer.searchKey(author);
                        return _AuthorCard(
                          key: ValueKey('author-card-$key'),
                          name: author,
                          bookCount: controller.authorBookCount(key),
                          onTap: () => Get.toNamed(
                            Routes.shelf,
                            arguments: ShelfArgs(authorKey: key),
                          ),
                          onLongPress: () =>
                              _showRenameDialog(context, key, author),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Kitapları açmak için dokun; adı değiştirmek için kartın '
                'köşesindeki kalem simgesine dokun.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    String authorKey,
    String displayName,
  ) async {
    final newName = await showAuthorRenameDialog(
      context,
      currentName: displayName,
      spellings: controller.authorSpellings(authorKey),
      affectedBooks: controller.authorBookCount(authorKey),
    );
    if (newName == null || newName == displayName) return;

    final changed = await controller.renameAuthor(authorKey, newName);
    if (changed > 0) {
      // Keşke 44 (1.25.0): önemli haber şeritle söylenir, balonla değil.
      haberSeridiGoster(
        baslik: 'Yazar güncellendi',
        mesaj: '$changed kitap "$newName" olarak yazıldı.',
      );
    }
  }
}

class _AuthorCard extends StatelessWidget {
  const _AuthorCard({
    super.key,
    required this.name,
    required this.bookCount,
    required this.onTap,
    required this.onLongPress,
  });

  final String name;
  final int bookCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Baş harf olduğu gibi kullanılır: Türkçe I/İ dönüşümü yanlış harf
    // üretebilir ('i'.toUpperCase() → 'I'), bu yüzden dönüştürülmez.
    final initial = name.isEmpty ? '?' : name.characters.first;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Text(
                      initial,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text('$bookCount kitap', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          // Keşke 19 (1.20.0): ad değiştirme artık görünür düğme —
          // "sayfanın en altındaki minik yazıyı okumadım" notu.
          // Basılı tutma yolu da aynı diyaloğu açmaya devam eder.
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              key: ValueKey('author-edit-${TextNormalizer.searchKey(name)}'),
              tooltip: 'Adını değiştir',
              icon: const Icon(Icons.edit_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: onLongPress,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

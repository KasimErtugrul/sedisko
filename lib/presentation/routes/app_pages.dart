import 'package:get/get.dart';

import '../../data/datasources/open_library_remote_datasource.dart';
import '../../data/services/book_photo_picker.dart';
import '../../data/services/cover_photo_store.dart';
import '../../domain/repositories/book_repository.dart';
import '../controllers/book_form_controller.dart';
import '../controllers/library_controller.dart';
import '../controllers/openlibrary_search_controller.dart';
import '../controllers/scanner_controller.dart';
import '../pages/book_detail_page.dart';
import '../pages/book_form_page.dart';
import '../pages/borrowed_page.dart';
import '../pages/loans_page.dart';
import '../pages/move_plan_page.dart';
import '../pages/organize_preview_page.dart';
import '../pages/organize_setup_page.dart';
import '../pages/scanner_page.dart';
import '../pages/search_page.dart';
import '../pages/shelf_editor_page.dart';
import '../pages/shelf_page.dart';
import '../pages/shell_page.dart';
import '../pages/splash_page.dart';
import '../pages/wishlist_page.dart';
import 'app_routes.dart';
import 'route_args.dart';

class AppPages {
  const AppPages._();

  static final List<GetPage<dynamic>> pages = [
    // Açılış karşılama ekranı ('sedişko', 1.25.0): bekletme süresi
    // dolunca ana sayfaya geçilir ve yığından silinir.
    GetPage(name: Routes.splash, page: () => const SplashPage()),
    GetPage(name: Routes.home, page: () => const ShellPage()),
    GetPage(
      name: Routes.shelf,
      page: () {
        final args = Get.arguments;
        final shelfArgs = args is ShelfArgs ? args : const ShelfArgs();
        return ShelfPage(
          shelf: shelfArgs.shelf,
          authorKey: shelfArgs.authorKey,
        );
      },
    ),
    GetPage(
      name: Routes.scanner,
      page: () => const ScannerPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut<ScannerController>(() => ScannerController());
      }),
    ),
    GetPage(
      name: Routes.form,
      page: () => const BookFormPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut<BookFormController>(
          () => BookFormController(
            Get.find<BookRepository>(),
            Get.find<LibraryController>(),
            photoStore: Get.find<CoverPhotoStore>(),
            photoPicker: Get.find<BookPhotoPicker>(),
          ),
        );
      }),
    ),
    GetPage(
      name: Routes.detail,
      // Kitap kimliği rota kurulum anında okunup sayfaya sabitlenir:
      // yığındaki detay sayfaları birbirinin argümanını ezmesin.
      page: () {
        final arg = Get.arguments;
        if (arg is String && arg.isNotEmpty) {
          return BookDetailPage(bookId: arg);
        }
        if (arg is Map) {
          final id = arg['id'] ?? arg['bookId'];
          if (id is String && id.isNotEmpty) {
            return BookDetailPage(bookId: id);
          }
        }
        return const BookDetailPage();
      },
    ),
    // Raf düzeni asistanı sayfaları; denetleyici InitialBinding'de kalıcıdır.
    GetPage(name: Routes.shelfEditor, page: () => const ShelfEditorPage()),
    GetPage(name: Routes.organizeSetup, page: () => const OrganizeSetupPage()),
    GetPage(
      name: Routes.organizePreview,
      page: () => const OrganizePreviewPage(),
    ),
    GetPage(name: Routes.organizePlan, page: () => const MovePlanPage()),
    // Open Library başlık/yazar araması (1.18.0); denetleyici sayfa açılışında
    // kurulur ve her ziyarette temiz bir arama alanı sunar.
    GetPage(
      name: Routes.search,
      page: () => const SearchPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut<OpenLibrarySearchController>(
          () => OpenLibrarySearchController(
            Get.find<OpenLibraryRemoteDataSource>(),
          ),
        );
      }),
    ),
    // Satın alınacaklar; denetleyici InitialBinding'de kalıcıdır.
    GetPage(name: Routes.wishlist, page: () => const WishlistPage()),
    // Ödünç verilenler / ödünç aldıklarım; denetleyici kalıcıdır.
    GetPage(name: Routes.loans, page: () => const LoansPage()),
    GetPage(name: Routes.borrowed, page: () => const BorrowedPage()),
  ];
}

import 'package:get/get.dart';

import '../../domain/repositories/book_repository.dart';
import '../controllers/book_form_controller.dart';
import '../controllers/library_controller.dart';
import '../controllers/scanner_controller.dart';
import '../pages/book_detail_page.dart';
import '../pages/book_form_page.dart';
import '../pages/scanner_page.dart';
import '../pages/shelf_page.dart';
import '../pages/shell_page.dart';
import 'app_routes.dart';
import 'route_args.dart';

class AppPages {
  const AppPages._();

  static final List<GetPage<dynamic>> pages = [
    GetPage(name: Routes.home, page: () => const ShellPage()),
    GetPage(
      name: Routes.shelf,
      page: () {
        final args = Get.arguments;
        return ShelfPage(shelf: args is ShelfArgs ? args.shelf : null);
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
          ),
        );
      }),
    ),
    GetPage(name: Routes.detail, page: () => const BookDetailPage()),
  ];
}

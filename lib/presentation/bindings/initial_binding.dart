import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/book_local_datasource.dart';
import '../../data/datasources/open_library_remote_datasource.dart';
import '../../data/repositories/book_repository_impl.dart';
import '../../domain/repositories/book_repository.dart';
import '../controllers/library_controller.dart';

class InitialBinding extends Bindings {
  InitialBinding(this._prefs);

  final SharedPreferences _prefs;

  @override
  void dependencies() {
    Get.put<BookLocalDataSource>(BookLocalDataSource(_prefs), permanent: true);
    Get.put<OpenLibraryRemoteDataSource>(
      OpenLibraryRemoteDataSource(http.Client()),
      permanent: true,
    );
    Get.put<BookRepository>(
      BookRepositoryImpl(
        local: Get.find<BookLocalDataSource>(),
        remote: Get.find<OpenLibraryRemoteDataSource>(),
      ),
      permanent: true,
    );
    Get.put<LibraryController>(
      LibraryController(Get.find<BookRepository>()),
      permanent: true,
    );
  }
}

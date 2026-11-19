import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/book_local_datasource.dart';
import '../../data/datasources/open_library_remote_datasource.dart';
import '../../data/datasources/shelf_local_datasource.dart';
import '../../data/repositories/book_repository_impl.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/backup_transfer.dart';
import '../../data/services/book_photo_picker.dart';
import '../../data/services/cover_photo_store.dart';
import '../../domain/repositories/book_repository.dart';
import '../controllers/backup_controller.dart';
import '../controllers/library_controller.dart';
import '../controllers/shelf_organize_controller.dart';

class InitialBinding extends Bindings {
  InitialBinding(this._prefs);

  final SharedPreferences _prefs;

  @override
  void dependencies() {
    Get.put<BookLocalDataSource>(BookLocalDataSource(_prefs), permanent: true);
    // Raf tanımları + taşıma planı deposu (shelves_v1, organize_plan_v1).
    Get.put<ShelfLocalDataSource>(
      ShelfLocalDataSource(_prefs),
      permanent: true,
    );
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
    // Kitap fotoğraflarının kalıcı deposu; silme temizliğinde de kullanılır.
    Get.put<CoverPhotoStore>(CoverPhotoStore(), permanent: true);
    // Kamera/galeri kaynağı; form fotoğraf bölümünde kullanılır.
    Get.put<BookPhotoPicker>(
      ImagePickerBookPhotoPicker(),
      permanent: true,
    );
    Get.put<LibraryController>(
      LibraryController(
        Get.find<BookRepository>(),
        coverStore: Get.find<CoverPhotoStore>(),
      ),
      permanent: true,
    );
    // Raf düzeni asistanı; Raflar sekmesi ve kurulum/plan sayfaları paylaşır.
    Get.put<ShelfOrganizeController>(
      ShelfOrganizeController(shelfStore: Get.find<ShelfLocalDataSource>()),
      permanent: true,
    );
    // Yedekleme ve aktarım (Ayarlar sekmesi); gerçek paylaşım/dosya seçim
    // sarmalayıcıları sistem paylaşım menüsünü ve dosya seçiciyi açar.
    Get.put<BackupService>(
      BackupService(
        bookStore: Get.find<BookLocalDataSource>(),
        shelfStore: Get.find<ShelfLocalDataSource>(),
      ),
      permanent: true,
    );
    Get.put<BackupController>(
      BackupController(
        service: Get.find<BackupService>(),
        sharer: const SharePlusSharer(),
        filePicker: const FilePickerBackupPicker(),
        fileSink: TempFileBackupSink(getTemporaryDirectory),
      ),
      permanent: true,
    );
  }
}

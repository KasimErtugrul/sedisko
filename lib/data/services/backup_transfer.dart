import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Yedek dosyasını paylaşan soyutlama.
///
/// Gerçek uygulamada sistem paylaşım menüsünü (WhatsApp, e-posta…)
/// açar; testlerde sahte ile düğmenin doğru dosyayı paylaştığı doğrulanır.
abstract class BackupSharer {
  const BackupSharer();

  /// [path] konumundaki dosyayı sistem paylaşım menüsüyle paylaşır.
  /// [subject] paylaşım başlığıdır (mail konusu olarak da kullanılır).
  Future<void> shareFile(String path, String subject);
}

/// share_plus 11 ile gerçek paylaşım; sistem paylaşım sayfası
/// WhatsApp dahil tüm yüklü uygulamaları listeler.
class SharePlusSharer extends BackupSharer {
  const SharePlusSharer();

  @override
  Future<void> shareFile(String path, String subject) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: subject,
        title: subject,
      ),
    );
  }
}

/// Kullanıcının seçtiği yedek dosyasının içeriği.
class BackupPickedFile {
  const BackupPickedFile({required this.name, required this.content});

  /// Dosyanın görünen adı (bilgi amaçlı).
  final String name;

  /// Dosyanın TÜM metin içeriği; doğrulama bunun üzerinde yapılır.
  final String content;
}

/// Yedek dosyası adı üreticisi: `kitapligim_yedek_2026-11-19_1430.json`.
class BackupFileNames {
  const BackupFileNames._();

  static String forDateTime(DateTime time) {
    String p(int v) => v.toString().padLeft(2, '0');
    return 'kitapligim_yedek_'
        '${time.year}-${p(time.month)}-${p(time.day)}'
        '_${p(time.hour)}${p(time.minute)}.json';
  }
}

/// Yedek dosyasını cihazda üreten soyutlama.
///
/// Denetleyici dosya YAZMAK bilmek zorunda değildir: içeriği verir,
/// yol geri alır. Testlerde sahte ile içerik/patyolaşma doğrulanır.
abstract class BackupFileSink {
  const BackupFileSink();

  /// Yedek içeriğini kalıcı bir dosyaya yazar ve yolunu döner.
  Future<String> write(String content);
}

/// Gerçek üretim havuzu: geçici klasöre `kitapligim_yedek_*.json` yazar.
class TempFileBackupSink extends BackupFileSink {
  TempFileBackupSink(this._tempDirResolver);

  final Future<Directory> Function() _tempDirResolver;

  @override
  Future<String> write(String content) async {
    final dir = await _tempDirResolver();
    final file = File(
      '${dir.path}/${BackupFileNames.forDateTime(DateTime.now())}',
    );
    await file.writeAsString(content, flush: true);
    return file.path;
  }
}

/// Yedek dosyasını cihazdan seçen soyutlama.
///
/// Dosya içeriğini OKUMAK da bu soyutlamanın işidir: böylece
/// denetleyici platform G/Ç'sinden arındırılır ve testlerde gerçek
/// dosya olmadan akış uçtan uca yürütülür.
abstract class BackupFilePicker {
  const BackupFilePicker();

  /// Kullanıcının seçtiği dosyanın içeriğini döner; vazgeçerse `null`.
  ///
  /// Dosya türü bilinçli olarak SERBEST seçilir: WhatsApp'ın kaydettiği
  /// dosya bazı cihazlarda uzantısız/sistem türsüz görünebilir. Doğrulamayı
  /// dosya içeriği üzerinde ([BackupEnvelope.parse]) yapmak, uzantı
  /// filtrelemesinden daha güvenilirdir.
  Future<BackupPickedFile?> pickJsonFile();
}

/// file_picker ile gerçek seçim ve okuma.
class FilePickerBackupPicker extends BackupFilePicker {
  const FilePickerBackupPicker();

  @override
  Future<BackupPickedFile?> pickJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    final file = result?.files.single;
    if (file == null) return null;
    final path = file.path;
    if (path == null) return null;
    final content = await File(path).readAsString();
    return BackupPickedFile(name: file.name, content: content);
  }
}

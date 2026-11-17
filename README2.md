# Kitaplığım (Flutter)

Evdeki kitaplığı raf, okuma tarihi ve kalınan sayfa bilgisiyle takip eder.

## Kurulum

```bash
flutter create --project-name kitaplik --org com.example kitaplik
# bu paketteki lib/ klasörünü ve pubspec.yaml dosyasını oluşan projenin üstüne kopyala
cd kitaplik
flutter pub get
flutter run
```

## Platform ayarları (kamera + internet)

**Android** — `android/app/src/main/AndroidManifest.xml` içinde `<manifest>` altına:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

`android/app/build.gradle(.kts)` içinde `minSdk` en az 23 olsun.

**iOS** — `ios/Runner/Info.plist` içine:

```xml
<key>NSCameraUsageDescription</key>
<string>Kitap barkodunu taramak için kamera gerekli.</string>
```

iOS minimum sürümü için `mobile_scanner` dokümanına bak (Podfile'da `platform :ios, '15.5'` gerekebilir).

## Mimari

```
lib/
├── core/            sabitler, hata sınıfı, tarih formatlayıcı
├── data/
│   ├── models/      BookModel (Equatable, JSON)
│   ├── datasources/ SharedPreferences (local) + Open Library (remote)
│   └── repositories/BookRepositoryImpl
├── domain/
│   └── repositories/BookRepository (soyut sözleşme; entity/usecase yok)
└── presentation/
    ├── bindings/    InitialBinding (DI)
    ├── controllers/ LibraryController, BookFormController, ScannerController
    ├── pages/       Home, Detail, Form, Scanner
    ├── routes/      Routes, AppPages, BookFormArgs
    └── widgets/     BookTile, CoverImage
```

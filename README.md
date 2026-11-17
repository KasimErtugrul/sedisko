# Kitaplığım (Flutter)

Evdeki kitaplığı **raf**, **okuma durumu/tarihi** ve **kalınan sayfa** bilgisiyle takip eder.
ISBN barkodu tarayıp kitap bilgilerini **Open Library**'den çeker; bilgiler yerel
olarak `SharedPreferences` içinde saklanır.

Bu sürüm, orijinal `sedisko` deposunun satır satır denetlenip düzeltildiği
**denetimli sürümdür**. Alttaki "Düzeltilen sorunlar" bölümünde her değişikliğin
nedeni açıklanır.

## Kurulum

```bash
flutter pub get
flutter run
```

> Not: Orijinal repodaki `pubspec.lock`, `pubspec.yaml` kısıtlarıyla tutarsızdı
> (ör. `mobile_scanner ^7.5.0` yerine `2.1.8` kilitliydi); bu yüzden lock dosyası
> silindi ve bu pakete güncel, tutarlı bir lock ile yeniden dahil edildi.

## Platform ayarları (kamera + internet)

**Android** (`android/app/src/main/AndroidManifest.xml`) — bu depoda hazır:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

`android/app/build.gradle.kts` içinde `minSdk = 23`.

**iOS** (`ios/Runner/Info.plist`) — bu depoda hazır:

```xml
<key>NSCameraUsageDescription</key>
<string>Kitap barkodunu taramak için kamera gereklidir.</string>
```

iOS deployment target `15.5`'e yükseltildi ve eksik `ios/Podfile` eklendi.

**macOS** — kamera açıklaması ve `com.apple.security.device.camera` entitlement'ı
hem Debug hem Release profile eklendi.

## Mimari

```
lib/
├── core/            sabitler, hata sınıfları, yardımcılar
│   ├── constants/   API + depolama + ayar anahtarları, sürüm bilgisi
│   ├── errors/      NetworkException, StorageException
│   └── utils/       tarih formatlayıcı, ISBN doğrulayıcı,
│                    Türkçe metin normalizasyonu, platform desteği
├── data/
│   ├── models/      BookModel + ReadingLogEntry (Equatable, savunmacı JSON)
│   ├── datasources/ SharedPreferences (yerel) + Open Library (uzak)
│   └── repositories/BookRepositoryImpl
├── domain/
│   ├── repositories/BookRepository (soyut sözleşme; entity/usecase yok)
│   └── services/    ReadingStats (okuma istatistiği hesabı)
└── presentation/
    ├── bindings/    InitialBinding (DI)
    ├── controllers/ Library, BookForm, Scanner, Settings
    ├── pages/       Shell (alt navigasyon), Shelves (raf kartları),
    │                Shelf (rafın kitapları), Detail, Form, Scanner, Settings
    ├── routes/      Routes, AppPages, BookFormArgs, ShelfArgs
    ├── utils/       AppHaptics (tercihe duyarlı titreşim)
    └── widgets/     BookTile, CoverImage, ReadingStatsPanel, StatusFilterRow
```

Bilinçli tasarım kararı: model doğrudan `domain` sözleşmesinde kullanılır
(ağır bir entity/usecase katmanı yoktur). Domain → data bağımlılığı bu
ölçekte kabul edilebilir bir kısayoldur; uygulama büyürse entity katmanı
eklenip model oraya taşınmalıdır.

## Güncelleme (yama uygulama) talimatı

Sürümler arası geçişte **tüm paketi**, kısmi dosya aktarımı değil, kullanın.
Sürümler birbirine bağlı dosyalar içerir: örneğin `LibraryController` ve
`ReadingStatsPanel`, `BookModel.readingLog` alanını kullanır. Yalnızca
controller/panel dosyalarını aktarırken eski bir `book_model.dart` yerinde
kalırsa derleme şöyle düşer:

```
Error: No named parameter with the name 'readingLog'.
Error: The getter 'readingLog' isn't defined for the type 'BookModel'.
```

Doğru güncelleme:

1. Bu paketteki `lib/` ve `test/` klasörlerini projenizdeki aynı adlı
   klasörlerle **tamamen değiştirin** (eskilerini silin, yenilerini kopyalayın).
2. `pubspec.yaml` ve `pubspec.lock`'u da güncelleyin.
3. `flutter pub get && flutter analyze && flutter test` ile doğrulayın.

Kitap verileriniz cihazda `SharedPreferences` içinde saklandığı için kod
altının değişmesi kitaplığı etkilemez; depolama anahtarı (`books_v1`)
değişmedikçe veriler korunur.

## Testler

```bash
flutter test
```

| Dosya | Kapsam |
| --- | --- |
| `test/core/isbn_validator_test.dart` | ISBN-10/13 kontrol haneleri, X desteği |
| `test/core/text_normalizer_test.dart` | Türkçe İ/ı arama eşleşmesi, alfabetik sıra |
| `test/data/book_model_test.dart` | JSON gidiş-dönüş, bozuk JSON dayanıklılığı, copyWith |
| `test/data/book_local_datasource_test.dart` | upsert/delete, paralel yazma, bozuk kayıt yalıtımı |
| `test/data/reading_log_entry_test.dart` | okuma günlüğü kaydı: savunmacı JSON, eşitlik |
| `test/domain/reading_stats_test.dart` | günlük/toplam istatistik hesabı, Türkçe gün sıralaması |
| `test/presentation/library_controller_test.dart` | yükleme/kayıt/silme hata akışları, ilerleme geçişleri, arama |
| `test/presentation/library_controller_reading_log_test.dart` | fark tabanlı okuma günlüğü birleştirme |
| `test/presentation/library_controller_shelf_filter_test.dart` | raf anahtarları, kitap sayımı, raf/arama/durum filtresi bileşimi |
| `test/presentation/reading_stats_panel_test.dart` | istatistik paneli widget testi |
| `test/presentation/shell_page_test.dart` | alt navigasyon, yatay raf kartları, raf sayfasına geçiş, tema tercihi |
| `test/presentation/settings_controller_test.dart` | tema/özellik tercihlerinin kalıcılığı |
| `test/presentation/settings_page_test.dart` | ayarlar ekranı radyo/anahtar davranışı |
| `test/widget_test.dart` | Ana sayfa/ekleme menüsü/form doğrulama smoke testleri |

## Düzeltilen sorunlar

### Kritik

1. **iOS kamera çökmesi** — `ios/Runner/Info.plist`'te `NSCameraUsageDescription`
   yoktu; izin metni olmayan uygulamada kamera açılışı iOS'ta anında çöker.
   İzin metni eklendi (macOS için de).
2. **Sessiz veri kaybı** — `BookLocalDataSource.getBooks()` içindeki
   `catch (_) → []` tek bozuk kayıtta tüm kitaplığı yok ediyordu ve bir sonraki
   yazma bunu kalıcılaştırıyordu. Artık kayıtlar tek tek ayrıştırılır
   (`BookModel.tryFromJson`), bozuk kayıt atlanır, sağlamlar korunur.
3. **Detay ekranı cast çökmesi** — `Get.arguments as String` argüman yoksa/
   yanlışsa exception fırlatıyordu; artık savunmacı ayrıştırma + "kitap
   bulunamadı" ekranı var.
4. **Scanner'da siyah ekran** — `errorBuilder` yorum satırıydı; kamera izni
   reddedildiğinde kullanıcı açıklamasız siyah ekranda kalıyordu. İzin durumu
   anlatan hata ekranı + "Tekrar dene" eklendi.
5. **Tutarsız pubspec.lock** — lock, pubspec kısıtlarıyla uyuşmuyordu
   (`^7.5.0` vs `2.1.8`); silinip aynı SDK ile yeniden üretildi ve pakete dahil edildi.
6. **Kapalı test dosyası** — `test/widget_test.dart` tamamen yorumsuzdu ve
   var olmayan `MyApp`'e referans veriyordu; 6 gerçek test dosyasıyla değiştirildi.
7. **Eksik iOS Podfile** — CocoaPods tabanlı derleme için gerekli Podfile
   eklenmediğinden iOS derlemesi kırılıyordu; standart Podfile eklendi.

### Yüksek

8. **Kaydetme/silme hataları görünmezdi** — `saveBook`/`deleteBook`/`loadBooks`
   hataları yakalanmıyordu; kullanıcıya anlaşılır mesaj gösterilir ve bellek
   yalnız depo başarılıysa güncellenir (metotlar `bool` döner).
9. **Yarış koşullu yazma** — paralel iki upsert okuma-güncelleme-yazma
   döngüsünde birbirini eziyordu; yazma işlemleri sıraya alındı
   (`_runSerialized`), setString `false` dönerse `StorageException` fırlatılır.
10. **ISBN-10 "X" yazılamıyordu** — sayısal klavye X içermediği için manuel
    ISBN-10 girişi imkânsızdı; metin klavyesi + kısıtlı formatter kullanılır.
11. **ISBN doğrulaması yoktu** — kontrol hanesi (mod 11 / mod 10) doğrulaması
    eklendi; aynı ISBN ile mükerrer kayıt formda ve tarama akışında engellenir.
12. **Form çift tıklama** — "Kaydet" çift tetiklenirse çift snackbar/yazma
    oluyordu; `isSaving` bayrağıyla korundu, buton spinner gösterir.
13. **Torch UI desenkronu** — `toggleTorch()` başarısız olursa (flaş yok) UI
    yanlış duruma geçiyordu; artık kontrolcünün gerçek durumundan
    (`scanner.value.torchState`) senkronlanır ve hata toast'lanır.
14. **Tarama sonrası kamera bırakma** — barkod okununca kamera durdurulmadan
    `Get.back()` yapılıyordu; artık `stop()` sonrası dönüş yapılır ve dokunsal
    geri bildirim verilir.
15. **Kapak görselleri belleği şişiriyordu** — `Image.network`'e
    `cacheWidth` (devicePixelRatio'ya göre), `loadingBuilder` ve
    `gaplessPlayback` eklendi.
16. **Silme akışı** — silme isteği başarısız olsa bile detay sayfasından
    çıkılıyordu; artık yalnız başarılı silmede sayfa kapanır.
17. **Sayfa güncelleme diyaloğu sessiz no-op'tu** — boş/geçersiz girişte
    "Kaydet" hiçbir şey yapmıyordu; `errorText` ile doğrulama eklendi.

### Orta

18. **Türkçe arama** — `İstanbul` ile `istanbul` eşleşmiyordu (İ küçültülünce
    birleştirici nokta üretiyor); `TextNormalizer.searchKey` ile çözüldü, aramaya
    ISBN de dahil edildi.
19. **Türkçe sıralama** — `compareTo` ASCII sıralaması `ç/ğ/ş`'yi sona atıyordu;
    Türkçe alfabe sırası `TextNormalizer.compareTr` ile uygulandı, boş raf
    etiketleri ("Rafsız") listenin sonuna taşındı.
20. **Çakışmaya açık ID** — `microsecondsSinceEpoch` tek başına çakışma riski
    taşıyordu; sıra sayacı + rastgele ek ile güçlendirildi.
21. **Desteklenmeyen platformlarda tarayıcı butonu** — Windows/Linux'ta
    mobile_scanner çalışmaz; `PlatformSupport.supportsBarcodeScan` ile ilgili
    butonlar gizlenir.
22. **Marka tutarsızlığı** — `android:label="sedisko"` ve iOS
    `CFBundleDisplayName="Sedisko"` iken uygulama içi ad "Kitaplığım" idi;
    üçü de "Kitaplığım" yapıldı.
23. **Ağ hata mesajları** — zaman aşımı, geçersiz yanıt ve bağlantı hataları
    ayrıştırılıp anlaşılır Türkçe mesajlara çevrildi.
24. **Repo hijyeni** — 3 MB'lık `sedisko.zip` (build çıktıları dahil) ve
    ephemeral dosyalar depodan çıkarıldı; `.gitignore` güncellendi.
25. **Erişilebilirlik küçük dokunuşları** — ilerleme çubuğuna `Semantics`
    etiketi, tile'larda `ValueKey`, dokunsal geri bildirim eklendi.
26. **Dark mode** — `themeMode: ThemeMode.system` açıkça belirtildi.

### Sıcak düzeltme (1.1.1)

27. **Barkod akışında tip çökmesi** — `Get.toNamed<String>(Routes.scanner)`
    runtime'da `type 'GetPageRoute<dynamic>' is not a subtype of type
    'Route<String?>?'` hatasıyla çöküyordu: GetX rotaları
    `GetPageRoute<dynamic>` olarak kurar, Flutter Navigator ise `pushNamed`
    generic'ine göre rotayı `Route<String?>`'e cast eder. `scanIsbn`
    (BookFormController) ve `addByScan` (LibraryController) generic'siz
    çağrıya çevrildi; dönen sonuç `is String` ile savunmacı biçimde
    ele alınıyor ve boş değer güvenle yok sayılıyor.

### Yeni özellikler (1.2.0)

28. **Okuma istatistikleri** — kitaba başlama/bitiş tarihi ve kalınan sayfa
    zaten tutuluyordu; artık her kaydetme bu durum farkından otomatik bir okuma
    günlüğü türetir (`BookModel.readingLog`). Detay sayfasının altında
    `ReadingStatsPanel` var: toplam sayfa, okuma günü, gün başına ortalama,
    en verimli gün ve son 14 günün mini grafı. Kayıtlar tek merkezde
    (`saveBook`) birleştirilir; elle geriye çekilen sayfalar negatif sayılmaz,
    "Başlanmadı"ya dönüş günlüğü temizler.
29. **Ana sayfada raf yönetimi (20+ raf / 200+ kitap ölçeği)** — uzun liste
    üç katmanla çözüldü:
    - **Katlama:** her raf bölümü başlığa dokunarak açılır/kapanır
      (`collapsedShelves`); kapalı bölüm yalnız tek başlık satırıdır.
    - **Raf çipleri + sayılar:** arama alanının altında yatay çip satırı
      (`"Roman (42)"`) ile tek dokunuşta rafa filtreleme; rafsız kitaplar
      için "Rafsız" çipi.
    - **Raflar sayfası:** AppBar'daki liste butonu tüm rafları kitap
      sayılarıyla listeleyen alt sayfayı açar.
    - Liste `ListView.builder` ile sanallaştırıldı: yalnız görünür öğeler
      kurulur, katlanmış bölümler maliyet üretmez.

### Yeni özellikler (1.3.0)

30. **Alt navigasyonlu ana sayfa** — ekranın altında `NavigationBar` var:
    **Raflar** ve **Ayarlar** sekmeleri. Raflar sekmesinde raflar dikey liste
    yerine **yatay kart şerididir** (raf adı + kitap sayısı); "Tüm kitaplar"
    ve varsa "Rafsız" kartı da şeritte. Karta dokununca o rafın kitapları
    **ayrı bir sayfada** açılır (durum filtresi çipleriyle). Arama yazılınca
    kart şeridi yerine sonuç listesi gelir. Önceki katlanır bölüm/çip
    düzeni ve "Raflar" alt sayfası bu seyir modelinin yerini aldı; liste
    `ListView.builder` ile sanallaştırılmaya devam eder, `IndexedStack`
    sekme durumunu korur.
31. **Ayarlar sayfası** — iki bölüm:
    - **Görünüm:** tema modu seçimi (Sistem varsayılanı / Aydınlık /
      Karanlık). Seçim `GetMaterialApp.themeMode`'a bağlıdır; değişiklik
      anında uygulanır ve `settings_theme_mode` anahtarıyla kalıcıdır,
      uygulama tercih edilen temayla açılır.
    - **Uygulama içi özellikler:** kapak görselleri (internetten kapak
      yüklemesini kapatır), barkod tarama düğmeleri (platform desteğiyle
      birlikte değerlendirilir), titreşimli geri bildirim (tarama ve
      dokunuşlardaki haptik; `AppHaptics` üzerinden). Tüm tercihler
      `settings_*` anahtarlarıyla SharedPreferences'ta saklanır.

## Sürüm notları

`pubspec.yaml` sürümü `1.3.0+5`'e yükseltildi. Depolama anahtarları
(`books_v1` ve `settings_*`) değişmedi: mevcut kullanıcılar kitaplıklarını
kaybetmez; okuma günlüğü alanı (`readingLog`) eski kayıtlarda boş gelir ve
ilk kayıttan itibaren derlenmeye başlar.

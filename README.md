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
<!-- 1.18.0: günlük okuma hatırlatıcısı -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
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
│   └── services/    ReadingStats (okuma istatistiği), BookSorter (sıralama)
└── presentation/
    ├── bindings/    InitialBinding (DI)
    ├── controllers/ Library, BookForm, Scanner, Settings
    ├── pages/       Shell (alt navigasyon), Shelves (raf kartları),
    │                Shelf (rafın kitapları + yazar filtresi), Detail,
    │                Form, Scanner, Settings
    ├── routes/      Routes, AppPages, BookFormArgs, ShelfArgs
    ├── utils/       AppHaptics (tercihe duyarlı titreşim)
    └── widgets/     BookTile, CoverImage, ReadingStatsPanel, StatusFilterRow,
                     ShelfPickerSheet (raf seçici/taşıma), SortSheet (sıralama)
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
| `test/domain/book_sorter_test.dart` | 9 alanın artan/azalan sıralaması, eksik değerlerin sonda kalması, Türkçe alfabe, basım yılı ayıklama |
| `test/presentation/library_controller_test.dart` | yükleme/kayıt/silme hata akışları, ilerleme geçişleri, arama |
| `test/presentation/library_controller_sort_test.dart` | aktif sıralama state'i, filtre+sıralama birleşimi, sortedAll izolasyonu |
| `test/presentation/library_controller_reading_log_test.dart` | fark tabanlı okuma günlüğü birleştirme |
| `test/presentation/library_controller_shelf_filter_test.dart` | raf anahtarları, kitap sayımı, raf/arama/durum filtresi bileşimi |
| `test/presentation/library_controller_move_test.dart` | raf taşıma (tek/toplu), günlük korunur, kısmi toplu taşınma |
| `test/presentation/library_controller_author_copies_test.dart` | yazar birleştirme/sıralama, yazar filtresi, kopya bulma |
| `test/presentation/library_controller_author_rename_test.dart` | yazar adı değiştirme/birleştirme: varyant yazımlar, yan yazar korunumu, depo hatasında kısmi güncelleme |
| `test/presentation/authors_page_test.dart` | Yazarlar sekmesi: grid, kitap sayısı, yazarın kitaplarına geçiş, uzun basma ile birleştirme |
| `test/presentation/shelf_page_author_rename_test.dart` | yazar görünümünde adlandırma aksiyonu, filtre anahtarı güncellenmesi, boş ad doğrulaması |
| `test/presentation/app_navigation_test.dart` | AppNav.pop: GetX 4.x snackbar hijack regresyonu, bildirim açıkken ekleme akışı |
| `test/presentation/library_controller_favorite_test.dart` | favori çevrimi, ana sayfa bölüm sorguları |
| `test/presentation/shelf_page_filter_test.dart` | yazar filtresi sayfası/banner, rafa toplama, uzun basma taşıma |
| `test/presentation/book_detail_move_test.dart` | raf kartından taşıma, kopyalar kartı, aynı ISBN kopya akışı |
| `test/presentation/home_page_test.dart` | ana sayfa özeti, bölüm şeritleri, arama görünümü |
| `test/presentation/sort_sheet_test.dart` | sıralama alt sayfası: yön segmenti, alan seçimi, liste düzeni koordinatla doğrulanır |
| `test/presentation/reading_stats_panel_test.dart` | istatistik paneli widget testi |
| `test/presentation/shell_page_test.dart` | alt navigasyon, yatay raf kartları, raf sayfasına geçiş, tema tercihi |
| `test/presentation/settings_controller_test.dart` | tema/özellik tercihlerinin kalıcılığı |
| `test/presentation/settings_page_test.dart` | ayarlar ekranı radyo/anahtar davranışı |
| `test/core/app_palette_test.dart` | palet tanımları, özel renk çözümlemesi, ölçek kademeleri |
| `test/presentation/settings_appearance_test.dart` | palet/özel renk/yazı boyutu seçimi, temaya sirayet, kalıcılık |
| `test/presentation/responsive_shell_test.dart` | dar↔geniş kabuk: NavigationBar ↔ NavigationRail, durum korunumu |
| `test/presentation/tablet_layout_test.dart` | tablet düzeni: tavan genişlik, adaptif grid, dar ekran davranışı |
| `test/presentation/overflow_guard_test.dart` | taşma savunması: 3 yüzey × 2 yazı boyutu × 4 sekme |
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

### Yeni özellikler (1.4.0)

32. **Kitap odaklı ana sayfa** — "Ana Sayfa" sekmesi artık yalnız raf
    kartları değil, kitaplıktan canlı bir özet akışı sunar:
    - **Özet satırı:** toplam / okunuyor / bitti sayıları tek bakışta.
    - **Devam eden kitaplar:** okumada olan kitapların yatay kapak şeridi.
    - **Favoriler:** favori işaretli kitapların yatay kapak şeridi.
    - **Not aldıkların:** notu olan kitapların yatay kapak şeridi.
    - **Tüm kitaplar:** kitaplığın tamamı `ListView.builder` ile
      sanallaştırılmış listede. Kapak kartına ya da tile'a dokununca detay
      sayfası açılır; boş bölümler yer tutmaz. Arama yazılınca akış yerine
      durum filtresi çipleriyle sonuç listesi çıkar.
33. **Favoriler** — `BookModel.isFavorite` alanı eklendi (eski veride alan
    yoktur, varsayılan kapalı; `books_v1` anahtarı değişmedi):
    - Detay sayfası AppBar'ındaki kalp butonu tek dokunuşla favoriyi açar/
      kapatır; okuma durumu, sayfa ve günlük değişmez.
    - Kitap formunda "Favori" anahtarı ile ekleme/düzenleme sırasında
      işaretlenebilir.
    - Liste satırlarında ve ana sayfa kapak kartlarında küçük kalp rozeti
      gösterilir.

### Yeni özellikler (1.5.0)

34. **Raf taşıma** — kitap artık rafından rafına taşınabiliyor:
    - Detay sayfasındaki **Raf kartına** dokununca raf seçici alt sayfası
      açılır: mevcut raflar + "Rafsız" + "Yeni raf..." (boş ya da mevcut
      bir rafın aksan/büyük harf ikizi olan ad reddedilir).
    - Raf sayfası ve ana listede **uzun basma** da aynı seçiciyi açar.
    - Taşıma okuma durumu, sayfa ve günlüğe dokunmaz (`saveBook`'a
      `deriveLog: false` ile yazılır; eski verideki boş günlüğe de kayıt
      eklenmez).
35. **Yazar filtresi + "Rafa topla" (genel filtreleme)** — raf sayfasının
    AppBar'ındaki süzgeç ikonu yazar seçim sayfası açar; seçim başlığı ve
    bir temizleme çipiyle listeyi daraltır. Yazar adları büyük harf/aksan
    farkları birleştirilerek gruplanır ("orhan pamuk" = "Orhan Pamuk") ve
    Türkçe alfabeyle sıralanır. Detay sayfasındaki yazar adına dokununca
    o yazarın kitapları açılır. Yazar filtresi aktifken AppBar'daki
    **drive_file_move ikonu aynı yazarın kitaplarını tek rafa toplar**;
    depo hatasında kısmi taşınma bilgi balonunda raporlanır ve raf-spesifik
    sayfada toplama sonrası kullanıcı raf kartlarına geri alınır.
36. **Kopya kitaplar (aynı kitabın birden fazla nüshası)** — her kopya
    **bağımsız bir kayıttır**: birinin okumaya başlaması diğerlerini
    etkilemez; her kopyanın durumu, sayfası ve günlüğü ayrıdır.
    - Aynı ISBN tekrar taranırsa diyalog çıkar: "Kitabı gör" ya da
      "Yeni kopya ekle" (ör. okunacak + rafa konulacak ikinci nüsha).
    - Formda aynı ISBN çakışması artık "Kopya olarak kaydet" onayı ister
      (yanlışlıkla çift kayıt yerine bilinçli kopya).
    - Detay sayfasında "Bu kitabın N kopyası daha var" kartı kopyaları raf
      ve durum bilgisiyle listeler; satıra dokununca o kopyanın detayı
      açılır (`preventDuplicates: false` — detay→detay geçişi GetX'in
      sessiz yoksaymasına takılmaz; kitap kimliği rota kurulumunda
      sabitlenir, yığındaki alt sayfa üsttekinin kitabına dönüşmez).
37. **Dar ekran taşmaları** — detay sayfasındaki "Okuma durumu" ve "Okuma
    İstatistikleri" başlık satırları dar telefonlarda taşma üretiyordu;
    başlıklar `Expanded` ile kırpılır hale getirildi.

### Yeni özellikler (1.6.0)

38. **Genel sıralama sistemi** — kitap listeleri artık 9 alan üzerinde
    artan/azalan sıralanabiliyor. Ana sayfa AppBar'ındaki ve raf sayfası
    AppBar'ındaki **sırala ikonu** aynı alt sayfayı açar: üstte **Artan /
    Azalan** segmenti, altta alan listesi:

    | Alan | Kaynak | Not |
    | --- | --- | --- |
    | Kitap adı | `title` | varsayılan sıralama (artan) |
    | Yazar | ilk yazar | çok yazarlı kitapta birincil yazar esas |
    | Yayınevi | `publisher` | |
    | Raf adı | `shelf` | Türkçe alfabe; rafsız sonda |
    | Sayfa sayısı | `pageCount` | 0 = bilinmiyor → sonda |
    | Okunulan sayfa | `currentPage` | 0 gerçek değerdir → sıralamaya girer |
    | Başlama tarihi | `startedAt` | tarihsizler sonda |
    | Bitirme tarihi | `finishedAt` | tarihsizler sonda |
    | Basım tarihi | `publishDate` | serbest metinden 19xx/20xx yılı ayıklanır; aynı yıl metin sırasıyla |

    Kurallar:
    - **Eksik bilgi her iki yönde de sona gider:** "Bitirme tarihi azalan"
      seçiminde bitmemiş kitaplar başa fırlamaz; bilinen tarihler
      sıralanır, tarihsizler sonda bekler.
    - **Türkçe alfabe:** metin alanları `TextNormalizer.compareTr` ile
      sıralanır (ç/ğ/ı/ö/ş/ü ASCII sonrasına değil alfabeye göre).
    - **Tek merkez:** sıralama `filteredBooks` (raf sayfası, arama
      sonuçları, yazar görünümü) ve `sortedAll` (ana sayfadaki "Tüm
      kitaplar" bölümü) çıktısına uygulanır; arama + durum + yazar
      filtreleriyle birleşir. `books` listesinin raf/ada düzeni (raf
      kartlarının beklediği) korunur.
    - **Aktif sıralama varsayılanından farklıysa** app bar ikonunda rozet
      çıkar; alt sayfada yön değişikliği sayfayı kapatmaz, alan seçimi
      kapatır ve liste anında güncellenir.

### Sıcak düzeltme (1.6.1)

39. **Flaky test giderildi: "İstatistik kutuları doğru değerleri gösterir"**
    yalnızca **00:00-02:00 saatleri arasında** çalıştırıldığında beklenmedik
    şekilde başarısız oluyordu. Neden: test verisi `DateTime.now()`'a göre
    kuruluyor, son kayıt "2 saat önce" gece yarısını aşınca takvim aralığı
    10 yerine 9 güne iniyor ve günlük ortalamadan **9.5 yerine 10.6**
    hesaplanıyordu. Düzeltme:
    - `ReadingStatsPanel` artık saat bağımlılığını enjekte edilebilir
      `now` parametresiyle alıyor (uygulamada davranış aynı: gerçek saat).
    - Panel testleri sabit saatle çalışır; gece yarısı sınırı için ayrı bir
      regresyon testi eklendi. Test takımı artık günün hangi saatinde ve
      hangi saat diliminde çalıştırılırsa çalıştırılsın aynı sonucu verir.

### Yeni özellikler (1.7.0)

40. **Manuel girişte kitap fotoğrafı** — kitabı elle giren kullanıcı artık
    kitabın fotoğrafını çekip kayda ekleyebiliyor. Formun üstündeki kapak
    bölümünde **"Kitabın fotoğrafını çek"** (kamera) ve **"Galeriden seç"**
    düğmeleri var; fotoğraf eklendikten sonra önizleme gösterilir ve
    **"Kaldır"** ile çıkarılabilir.

    Nasıl çalışır:
    - Yeni paketler: `image_picker` (kamera/galeri) ve `path_provider`
      (kalıcı klasör). Çekilen fotoğraf geçici klasörden uygulamanın
      belgeler dizini altındaki `covers/` klasörüne **kopyalanır**; kitap
      kaydında yalnız bu kalıcı yol saklanır (`coverPath` alanı, eski
      kayıtlarda boş gelir).
    - **Yerel fotoğraf önceliklidir:** fotoğraflı kitapta Open Library ağ
      kapağı yerine kullanıcının fotoğrafı gösterilir (liste, ana sayfa,
      detay ve form önizlemesi dahil). Fotoğraf internetten gelmediği için
      ayarlardaki "Kapak görselleri (internetten göster)" tercihinden
      bağımsızdır.
    - **Dosya temizliği:** fotoğraf değiştirilirse ara dosya, kayıt
      başarılıysa eski fotoğraf, kitap silinirse fotoğraf dosyası diskten
      silinir. Silme yalnız `covers/` klasörünün içindeki dosyalara
      dokunur.
    - **Platform:** kamera/galeri düğmeleri Android ve iOS'ta görünür
      (mobil odaklı özellik); Windows/Linux/macOS/web'de form yalnız ağ
      kapak önizlemesini gösterir. iOS için fotoğraf kitaplığı izni
      (`NSPhotoLibraryUsageDescription`) Info.plist'e eklendi; kamera izni
      açıklaması güncellendi. Android tarafında ek izin gerekmez.
    - Fotoğraf 1200 px genişlik / %80 kalite ile kaydedilir; liste ve
      detay gösterimi için yeterli, depolamada şişkinlik yapmaz.

### Sıcak düzeltme (1.7.1)

41. **Test düzeltmesi: "masaüstünde fotoğraf aksiyonları gizlenir" testi,
    eski Flutter SDK'arda "The value of a foundation debug variable was
    changed by the test" hatasıyla düşüyordu.** Test, masaüstü davranışını
    doğrulamak için `debugDefaultTargetPlatformOverride` değişkenini geçici
    olarak değiştiriyor; sıfırlama `addTearDown` ile yapılıyordu. Eski
    Flutter SDK'lar foundation değişken denetimini test gövdesi biter
    bitmez, `addTearDown` geri çağrıları çalışmadan önce yapar; bu
    sıralamada sıfırlama "geç" kalıyor ve gövde başarılı olsa bile invariant
    denetimi hata fırlatıyor. (Flutter 3.50'de denetim `postTest` aşamasına
    taşındı ve `addTearDown` ile sıfırlama destekleniyor.) Düzeltme:
    sıfırlama test gövdesi içinde `try/finally` ile yapılır — eski ve yeni
    SDK'larda aynı şekilde güvenlidir. Uygulama kodunda değişiklik yoktur.

### Yeni özellikler (1.8.0)

42. **Tüm kartlar tam bilgi gösterir** — kullanıcı isteğiyle uygulama
    içindeki her kart artık kitaba ve rafa ilişkin tüm bilgileri tek
    bakışta veriyor:
    - **Kitap satır kartları** (raf sayfası, arama sonuçları, yazar
      görünümü): başlık ve yazarın altında birleşik bilgi satırı — raf
      ("Rafsız" dahil), yayınevi, basım yılı, sayfa sayısı. Altında okuma
      durumu bloğu ve varsa bitirme hedefi satırı (gecikmişse hata
      rengiyle vurgulu).
    - **Ana sayfa kapak kartları** (şeritler): kapak altında başlık +
      yazar + durum/sayfa ("Sayfa 50/200", "320 sayfa", "Bitti • tarih") +
      raf satırı.
    - **Raf kartları** (Raflar sekmesi): artık yalnız ad + sayı değil;
      kitap sayısının altında "N okunuyor" ve "N bitti" kırılımı
      ("Tüm kitaplar" kartında genel kırılım).

43. **Bitirme hedefi** — kitaba "bu tarihe kadar bitireceğim" hedefi
    konabiliyor:
    - Formda "Bitirme hedefi (isteğe bağlı)" alanı: dokun → gelecek tarih
      seç (geçmiş tarih seçilemez), temizleme düğmesiyle kaldırılır.
      Kayıtta `targetFinishDate` alanına yazılır; eski kayıtlarda boş
      gelir.
    - **Detay sayfası:** hedefe kalan takvim günü ve günde okunması
      gereken sayfa planı ("günde ~20 sayfa okumalısın"); hedef günü
      "son gün!" uyarısı; tarihi geçen kitapta kaç gün geciktiği hata
      rengiyle gösterilir. Bitmiş kitapta hedefe göre sonuç: "hedefinden
      4 gün önce bitirdin" / "hedefi 3 gün aştın".
    - **Ana sayfa "Bitirme hedefleri" şeridi:** hedefli, bitmemiş kitaplar
      en yakın hedef önce (gecikenler en başta); kartlarda geri sayım
      ("12 gün kaldı" / "3 gün gecikti").
    - **Kartlarda:** hedef tarihi + kalan gün + günlük sayfa planı tek
      satırda; gecikme vurgulu.
    - Hesaplar takvim günü bazlıdır (`ReadingGoal` servisi, enjekte
      edilebilir saat): testler ve uygulama günün hangi saatinde
      çalışırsa çalışsın aynı sonucu verir.

44. **Ana sayfa düzeni yenilendi** —
    - **"Tüm kitaplar" listesi ana sayfadan kaldırıldı:** tam kitaplık
      artık Raflar sekmesindeki "Tüm kitaplar" kartından açılır. Ana
      sayfa özet + bölüm şeritlerine odaklandı; sıralama çıktısı arama
      sonuçları ve genel kitaplar sayfasında geçerlidir.
    - **"Favoriler" bölümü daima görünür:** hiç kitap favorilenmemişse
      bile bölüm başlığıyla birlikte "Henüz favori kitabın yok" ipucu
      kartı gösterilir; favorileştirmeyi keşfettirir.
    - **"En çok sayfalı kitaplar" şeridi:** sayfa sayısı bilinen en kalın
      10 kitap azalan sıralı (eşitlikte kitap adı, kararlı sıra).

### Navigasyon düzeltmesi + yeni özellikler (1.9.0)

45. **"Kaydet deyince bazen ana sayfaya atıyor" hatası giderildi** —
    GetX 4.x'in belgelenmemiş davranışı: `Get.back()`, **açık bir snackbar
    varsa onu kapatıp rota pop'u yapmadan döner** (get 4.7
    `extension_navigation.dart` içindeki uyumluluk kodu). Kullanıcı
    senaryosu: "Barkod tara → Open Library'de bulunamadı" bildirimi hâlâ
    ekrandayken (ilk ~3 saniye) hızlıca ana sayfaya dönüp **"Manuel ekle"ye**
    basılırsa, alt sheet'i kapatması gereken `Get.back()` bildirimi kapatır
    ve **sheet açık kalır**; form bu sheet'in üstüne biner. Kaydet
    deyince form kapanır ama altındaki sheet ana sayfada açık kalır:
    kullanıcı "okey tikine basınca ana sayfaya atıyor" algılar. Her
    seferinde değil, yalnız bildirim ekrandayken olur — tam olarak
    raporlanan "bazen" davranışı.

    Düzeltme: tüm sayfa/sheet/diyalog pop'ları için `AppNav.pop`
    yardımcısı eklendi (navigator doğrudan pop'lar; snackbar'lar root
    overlay girişleri olduğundan navigator pop'u onlardan etkilenmez).
    Ekleme menüsünün iki aksiyonu, form kaydı, tarayıcı dönüşü, ISBN
    çakışma/kopya diyaloğu, silme ve sayfa güncelleme diyaloğu, rafa
    toplama — hepsi bu yardımcıya geçirildi. Regresyon testleri ekredi:
    bildirim açıkken `Get.back()` gerçekten pop etmiyor, `AppNav.pop`
    ise pop ediyor; bildirim açıkken "Manuel ekle" akışında sheet kapalı
    ve form üstte oluyor.

46. **Yazarlar sekmesi: grid + yazım birleştirme** — kullanıcı isteğiyle
    "yazarlar diye bir buton" alt navigasyona eklendi:
    - **Yazarlar sekmesi (grid):** kitaplıktaki yazarlar baş harf
      avatarı + ad + kitap sayısıyla grid görünümünde listelenir;
      Türkçe alfabe sırasıyla. Karta dokununca yazarın kitapları
      açılır (kitap detayındaki yazar dokunuşuyla aynı sayfa; durum
      filtreleri ve sıralama çalışır).
    - **Yazım birleştirme (Kasim → Kasım):** Open Library verisi Türkçe
      karakterleri sadeleştirebildiği için aynı yazar "Kasım" ve
      "Kasim" yazımlarıyla kayıtlı olabilir; iki yazım da aynı arama
      anahtarına katlandığı için grid'de zaten tek kart görünür. Kart
      üzerinde **basılı tutunca** (ya da yazarın kitapları sayfasındaki
      "Yazarı yeniden adlandır" ikonuyla) açılan diyalog, arkadaki tüm
      yazımları listeler ve seçilen isimle **tüm kitaplarda** tek yazıma
      sabitler; aynı kitapta iki varyant varsa tek isimde birleşir, yan
      yazarlar ve okuma günlüğü korunur. Depo hatasında kalan kitaplar
      dokunulmaz (kısmi güncelleme bilgi balonunda raporlanır).

    Depolama anahtarı değişmedi (`books_v1`); yazar birleştirme yalnız
    kitapların `authors` alanını günceller.

### Ana sayfa yenilemesi + dosya hijyeni (1.10.0)

47. **Ana sayfa farklı gösterimlerle zenginleştirildi** — kullanıcı
    isteği: "ana sayfada farklı gösterimler sunalım... yatayda kayan
    listview'ler gridview'lerle coşturalım". Mevcut bölümlerin yanına
    yenileri eklendi; akış sırası:
    - **Özet satırı:** artık 4 sayaç — Toplam / Okunuyor / Bitti /
      **Favori** (yeni).
    - **Devam eden kitaplar** (mevcut, yatay şerit).
    - **Favoriler** (mevcut; boşken ipucu kartı, bölüm yer tutar).
    - **Bitirme hedefleri** (mevcut; geri sayımlı şerit, en yakın hedef
      önce, gecikmişler hata rengiyle).
    - **Son eklenenler (yeni):** kitaplar eklenme tarihi azalan, en
      fazla 10 kart; eşitlikte Türkçe kitap adı sırası.
    - **En çok sayfalı kitaplar** (mevcut).
    - **En çok kitaba sahip yazarlar (yeni):** yatay yazar kartları
      (baş harf avatarı + ad + kitap sayısı). Yazım katlaması korunur:
      "Kasım" ve "Kasim" tek kartta toplanır. Karta dokununca yazarın
      kitapları açılır; başlıktaki **"Tümü"** aksiyonu Yazarlar
      sekmesine geçirir.
    - **Rafların (yeni, gridview):** iki kolonlu raf kartları — raf adı,
      toplam kitap ve "N okunuyor • N bitti" özeti. Karta dokununca
      rafın kitap listesi açılır; **"Tümü"** Raflar sekmesine geçirir.
    - **Bu ay bitirdiklerin (yeni):** bu ay bitirilen kitaplar, en yeni
      bitiş önce. Ay sınırı takvim bazlıdır (yıl taşıması güvenli);
      bitiş tarihi girilmemiş eski "bitti" kayıtları yanlış ayda
      gösterilmez.
    - **Not aldıkların** (mevcut).

    Tüm bölümler kitap yoksa listeye girmez (yer tutmaz); Favoriler bu
    kuralın bilinçli istisnasıdır. Sekme geçişleri kabuğa (ShellPage)
    yeni eklenen geri çağrılarlarla yapılır; ana sayfa GetX dışında
    sekme durumu bilmez.

48. **Tanrı dosyası parçalandı** — kullanıcı isteği: "900 satırlı devasa
    dart dosyalarını istemiyoruz". 591 satırlık `home_page.dart` yalnız
    kompozisyon yapan küçük bir dosyaya indirildi; görsel parçalar
    `lib/presentation/widgets/home/` altında bölündü:
    `book_cover_card.dart` (tüm bilgileri gösteren kapak kartı),
    `book_strip.dart` (yatay kitap şeridi), `author_strip.dart` (yazar
    kartları), `shelf_summary_grid.dart` (raf grid'i),
    `home_section_header.dart` (başlık + "Tümü" + boş ipucu),
    `home_summary_row.dart` (özet), `home_empty_state.dart` (boş durum).
    Bölüm verileri yeni saf servis `lib/domain/services/home_feed.dart`
    içinde toplanır (`topAuthors`, `recentlyAdded`, `finishedThisMonth`);
    GetX bağımsız olduğu için arayüz olmadan test edilir.
    `LibraryController`'a yeni sorgu eklenmedi; mevcut sorgular korundu.

49. **Yazarlar sekmesi kartları dar ekranda taşıyordu** — 360–400 dp
    genişlikte yazar kartının içeriği (baş harf + iki satır ad + kitap
    sayısı) kart yüksekliğine sığmıyor, 13 px alt taşma (sarı-siyah
    çizgili alan) oluşuyordu. Kart oranı 0.9 → 0.8, avatar yarıçapı
    26 → 22 yapıldı; 400 dp test yüzeyinde doğrulandı.

### Ana sayfada boş bölümler asla gizlenmez (1.11.0)

50. **Boş bölüm gizlenmez, "Henüz ..." metniyle yer tutar** — kullanıcı
    isteği: "ana sayfada farklı kategoriler belirledik ya; o kategoride
    veri olmasa bile asla gizli kalmasın, yine gösterilsin kategori ama
    içinde 'henüz ........' diye bir metin yazabilir". 1.10.0'da yürürlükte
    olan "veri yoksa bölümler listeye girmez" kuralı tersine çevrildi:
    ana sayfanın dokuz bölümü de artık her koşulda görünür. Veri olmayan
    bölümün şerit yerine, konusuna uyan ikonla kısa bir ipucu kartı durur:
    - **Devam eden kitaplar:** "Henüz okumaya başladığın kitap yok."
    - **Favoriler:** "Henüz favori kitabın yok."
    - **Bitirme hedefleri:** "Henüz bitirme hedefi koyduğun kitap yok."
    - **En çok sayfalı kitaplar:** "Henüz sayfa sayısı girilmiş kitap yok."
    - **En çok kitaba sahip yazarlar:** "Henüz yazar bilgisi girilmiş
      kitap yok."
    - **Rafların:** "Henüz raf oluşturmadın."
    - **Bu ay bitirdiklerin:** "Bu ay henüz bitirdiğin kitap yok."
    - **Not aldıkların:** "Henüz not aldığın kitap yok."

    Her kartın ikinci satırı ne yapılacağını söyler (ör. "Kitap
    detayındaki kalp ikonuyla favorilerine ekleyebilirsin."). Böylece
    sayfa düzeni kitaplık durumuna göre oynamaz; kullanıcı bölüm
    yerini ezberler. "Son eklenenler" yalnız kitaplık tümüyle boşken
    zaten sayfa boş durumuyla karşılandığı için ipucu metni yine de
    tanımlıdır. `HomeSectionEmptyHint` bölüm bazlı ikon parametresi
    aldı; bölüm başlıkları ve ipucu kartları tek sanallaştırılmış
    listede yer tutmaya devam eder.

### Responsive + görünüm tercihleri (1.12.0)

51. **Tablet/yatay responsive düzen** — kullanıcı isteği: "uygulamanın
    tamamına hem tablette çalışacak responsive tasarıma geçelim…
    yatay döndürmeler için ayrıca… tablet için dikey ve yatayda da
    gerekli responsive ve layout tasarımından taviz vermeyelim".
    - **Kırılım disiplini:** tek eşik `AppBreakpoints.wide` (600 dp,
      `widgets/responsive/app_breakpoints.dart`). Dar ekran = telefon
      (alt bar), geniş ekran = tablet / yatay / masaüstü penceresi.
    - **Kabuk dönüşümü:** geniş ekranda alt [NavigationBar] yerini sol
      [NavigationRail]'e bırakır (`shell_page.dart`); iki gösterim aynı
      sekme listesini ve aynı [IndexedStack]'i kullanır — sekme arasında
      durum (arama alanı vb.) korunur.
    - **Tavan genişlik:** geniş ekranda raf kitap listesi (720), kitap
      detayı ve kitap formu (840) ve ayarlar (720) [ResponsiveCenter]
      ile ortalanır; satırlar iki uç arasında dağılıp okunamaz hale
      gelmez. Dar ekranda sarmalayıcı hiçbir etkisi yoktur.
    - **Adaptif grid:** ana sayfa "Rafların" grid'i ve Yazarlar grid'i
      zaten `maxCrossAxisExtent` ile kolon sayısını genişliğe göre
      büyütüyordu; tablette 4+ kolona açılır.
    - **Yönelim kapısı** (`orientation_gate.dart`): telefon (en kısa
      kenar < 600 dp) dikeye kilitli kalır; tablette dört yön serbest.
      Karar saf fonksiyondur (`orientationsFor(shortestSide)`) ve yalnız
      karar değiştiğinde platform kanalına yazılır.
52. **Ayarlar: renk paletleri + yazı boyutu** — kullanıcı isteği:
    "ayarlar kısmına kullanıcının seçeceği ve hazır olan renk paletleri
    olsun… yazı tipi boyutunu da ayarlayabilsin… koşulsuz şartsız tüm
    uygulamaya sirayet etsin".
    - **6 hazır palet** (`core/theme/app_palette.dart`): Varsayılan
      (mavi), Orman (yeşil), Gün Batımı (turuncu), Lavanta (mor), Deniz
      (camgöbeği), Gül (pembe).
    - **Özel renk:** yeni paket yok — hue + açıklık kaydırıcısı ve ton
      kareleriyle küçük bir seçici diyaloğu
      (`widgets/appearance/hue_color_picker.dart`); seçilen tohum rengi
      ARGB int olarak saklanır, geçersiz değerler savunmacı olarak
      varsayılan palete düşer.
    - **Yazı boyutu (4 kademe):** Küçük 0.85× / Normal 1.0× / Büyük
      1.15× / Çok büyük 1.3×; canlı önizleme kartıyla.
    - **Koşulsuz sirayet:** `GetMaterialApp` tohumu `ColorScheme.fromSeed`
      ile hem açık hem koyu şemaya işler; yazı boyutu `builder` içinde
      `MediaQuery.textScaler` olarak konur — hiçbir ekran kendi ölçeğini
      görmezden gelemez. Palet yalnız tohumu seçer; karanlık/aydınlık
      tercihi bağımsız kalır.
    - **Kalıcılık:** üç yeni `settings_*` anahtarı
      (`settings_palette_id`, `settings_custom_seed`,
      `settings_text_scale`); `books_v1` dokunulmaz.
53. **Taşma savunması** — kullanıcı kuralı: "overflow olma durumlarına
    karşı gerekli tedbirler alınsın". Kart metinleri zaten satır sınırı +
    üç nokta ile kırpılıyordu; üzerine bir savunma testi eklendi
    (`overflow_guard_test.dart`): 360/768/1280 dp genişlik × 0.85/1.3
    yazı boyutu × dört sekmenin tümünde, uzun başlık/yazar/yayınevi/
    hedef metinleriyle kurulurken tek taşma bile istisna düşmez.
    Ayarlar, palet ve ölçek seçici widget'ları `Wrap`/`ChoiceChip` ile
    dar ekranda alt alta sarılır; hiçbir satır sabit genişlik varsaymaz.
54. **Raf düzeni asistanı (hedef düzen + fiziksel taşıma planı)** —
    kullanıcı isteği: "yazarları bir rafta birleştireyim / yayınevine
    göre / isme göre / sayfa sayısına göre; 50 kitaplık rafa 80 kitabı
    birleştirmemeli; raflar taşmamalı veya eksik kalmamalı" ve "uygulama
    dese ki şu raflardaki şu kitapları şu rafa taşı — ev iki katlı, her
    kitap için in çık yapmak istemiyorum".
    - **Raf tanımları** (`shelves_v1`): ad + kapasite (kitap sayısı) +
      serbest yer etiketi ('Alt kat', 'Üst kat', …) + fiziksel sıra.
      Hızlı kurulum tek kapasiteyle 'Raf 1..N' açar; kitaplardaki mevcut
      raf adları ilk açılışta varsayılan kapasiteyle içe aktarılır. Raf
      adı değişirse kitaplara sirayet eder. Kitap ataması hâlâ
      `books_v1`'in `shelf` alanında; kitap verisi değişmez.
    - **Hedef düzen** (`domain/services/shelf_planner.dart`): yazar/
      yayınevi modunda gruplar kitap sayısı **çoktan aza** sıralanır
      (eşitlikte Türkçe alfabe) ve her grup BÜTÜN halinde ilk sığan rafa
      yerleşir (first-fit); küçük sonraki grup önceki rafın boşluğuna
      geri döner (raflar dolu kalır). En büyük raf kapasitesini aşan
      grup: sığan kadarı rafda, artığı 'Karışık kitaplar' rafında.
      İsim/sayfa modunda kitaplar akış gibi dizilir (A→Z, ince→kalın;
      eksik bilgi sonda), raf dolunca sıradakine geçilir. Hiçbir raf
      kapasitesini aşmaz; plan aynı girdiden aynı sonucu üretir.
    - **Fiziksel taşıma planı** (`domain/services/move_plan_builder.dart`):
      hedef düzenle mevcut durumun farkı tur tur yürüyüş senaryosuna
      çevrilir. Tur = tek yer (kat): aynı etiketli rafların işi tek
      turda toplanır, yer değişimi yalnız yığın başka yere gideceği
      zaman olur. Raf ziyaretinde "önce çıkanları AL, sonra gelenleri
      KOY" sırası korunur; elde taşınabilecek kitap sınırı (varsayılan
      10) aşılırsa alım aynı turun devamında bölünür. Plan kalıcıdır
      (`organize_plan_v1`); tur "Yaptım" işaretlendiğinde o turda KONAN
      kitapların rafı anında güncellenir (alınıp yolda olanlar
      yerleştikleri turda yazılır) — yarıda bırakılan plan "Yeniden
      planla" ile mevcut gerçekten yeniden kurulur, iptal kitaplara
      dokunmaz.
    - **Akış:** Raflar sekmesinde davet kartı / ilerleme bandı → kurulum
      (kriter + "Kitaplarımın tamamını girdim" onayı, tamlık onayı
      verilmeden başlamaz) → hedef düzen önizlemesi (raf raf kitap
      listesi + doluluk çubuğu; uyarılar en üstte; bir şey yazılmaz)
      → taşıma planı (tur tur, emir emir, "Yaptım") → plan bittiğinde
      anahtar silinir. Plandan sonra eklenen kitaplar "yeni gelenler"
      olarak bildirilir.
    - **Uyarılı elle taşıma:** raf seçicide tanımlı raflar artık
      '2/50' doluluk gösterir; dolu raf seçilince "Raf doluyor (50/50)"
      uyarısı çıkar, kullanıcı yine de taşıyabilir.

### Yedekleme ve aktarım (1.14.0)

55. **Kitaplık yedeği: tek dosya paylaş, tek dosyadan geri yükle** —
    kullanıcı isteği: "eşimde de bu uygulama var; ev kütüphanesini tek tek
    raf raf girdi. Keşke WhatsApp'tan bu veritabanını bir dosya halinde
    gönderebilse de bende tek tek uğraşmasam."
    - **Paylaş** (Ayarlar → Yedekleme ve aktarım): tüm kitaplar
      (`books_v1`) ve raf tanımları (`shelves_v1`) tek bir
      `kitapligim_yedek_<tarih>_<saat>.json` dosyasına yazılır ve
      sistem paylaşım menüsü açılır (WhatsApp, e-posta…). Dosya zarfı
      format etiketi (`kitapligim-yedek`) + sürüm taşır; kitaplık
      boşken paylaşım yapılmaz.
    - **İçe aktar**: WhatsApp'tan indirilen dosya seçilir; içerik uçtan
      uca doğrulanır (etiket/sürüm kontrolü + her kitap ve raf kaydının
      tek tek doğrulanması — bozuk tek kayıt tüm dosyayı geçersiz kılar,
      sessiz veri kaybı yok) ve kullanıcı kip seçer:
      - **Birleştir**: mevcut kitaplar korunur; ISBN ya da başlık+yazar
        eşleşmesi (Türkçe katlamayla: 'Dünya' = 'dunya') görenler
        atlanır. Raf adları eşleşirse (büyük/küçük harf duyarsız) mevcut
        raf aynen kullanılır ve kitabın raf alanı kanonik ada çekilir
        ('roman' → 'Roman'); kimlik çakışmaları yeni kimlikle çözülür.
      - **Üzerine yaz**: mevcut kitap ve raf tanımları silinip yedeğin
        içeriği geri yüklenir; sürüyor olan taşıma planı sıfırlanır.
        Kişisel tercihler (`settings_*`) her iki kipte de dokunulmaz.
    - Doğrulama depoya yazmadan ÖNCE yapılır (başarısız içe aktarma
      mevcut veriye dokunmaz); yazma başarılı olursa ana sayfa/Raflar
      sekmesi anında yenilenir. Yedek dosyası tüm kitaplığı içerir;
      alıcıyla paylaşırken dikkat edin.

56. **Favori raf + favori yazarlar + kalınlık duyarlı kapasite** —
    kullanıcı isteği: "raf düzenleme işleminde keşke öncelikle bana favori
    rafımı ve favori yazarlarımı sorsa; favori rafıma favori yazarlarımı
    görebilsem" ve "sayfa sayısı da önemliymiş; 40 kitap diyoruz ama çok
    kalın kitaplarla sığmıyor, 60 kitabın kapladığı yeri kaplıyor".
    - **Favoriler önce sorulur:** kurulumun ilk kartı Favoriler'dir.
      Favori raf ChoiceChip'lerle seçilir ('Yok' dahil), favori
      yazarlar serbest metinle çip olarak eklenir/silinir; altında
      kitaplıktaki yazarlardan en çok kitaplı 6 öneri çipi gelir
      (Türkçe katlamayla tekilleştirir). Tercihler kalıcıdır
      (`settings_favorite_shelf_id`, `settings_favorite_authors`,
      `settings_thickness_aware` — mevcut anahtarlar DEĞİŞMEDİ).
    - **Planlamada favoriler:** favori raf + favori yazarlar birlikte
      seçildiyse plan favori yazarların kitaplarını EN ÖNCE favori
      rafa dizer (yazarlar kullanıcının listediği sırayla, kitaplar
      adına göre). Sığmayan favori kitap kaybolmaz; kalan kitaplarla
      birlikte dağıtılır ve uyarılır. Favori rafın kalan boşluğu normal
      dağıtıma açıktır. Önizlemede favori raf yıldız rozetiyle
      işaretlenir; raf düzenleyicide favori rafın adının yanında
      yıldız görünür. Yalnız raf YA DA yazar seçildiyse (yarım tercih)
      plan değişmez.
    - **Kalınlık (birim) hesabı:** 'Kalın kitaplar daha çok yer kaplar'
      anahtarı (varsayılan AÇIK) kapasiteyi kitap sayısından YERE
      çevirir: ≈350 sayfa = 1 birim, 0,5 birim duyarlılıkla yuvarlanır
      (525 sayfa = 1,5 birim — kullanıcının "40 kalın = 60 normal"
      gözlemiyle uyumlu); sayfa sayısı bilinmeyen kitap 1 birimdir.
      Raf kapasitesi (kitap sayısı kalibrasyonu) birim bütçesine
      dönüşür; grup modu, akış modu ve Karışık rafı bütçeyle çalışır.
      Akış modunda sıradaki kitap artık sığmıyorsa sıradaki rafa geçilir
      — fiziksel kitaplık gibi, sıra bozulmaz. Doluluk çubukları
      kalınlık modunda '6 / 50 birim' biçiminde yazar; raf seçicideki
      doluluk ve "Raf doluyor" uyarısı da birimdedir. Anahtar kapalıyken
      davranış 1.14.0 ile birebir aynıdır (kitap sayısı).

57. **Kolaylık güncellemeleri: favori yazarlar ana sayfada, form
    iyileştirmeleri, raf grid'i ve raf toplu taşıma** — kullanıcı isteği:
    "ana sayfada da favoriye alınmış yazarları görmek istiyoruz; manuel
    eklemede kitap adı ve yayınevi de boşluktan sonra büyük harfe dönsün;
    yazar yazmaya başlayınca önceki yazarlar önerilsin; yazarken geri
    basınca yazdıklarım boşa gitmesin; ana sayfadaki filtre/sırala
    aksiyonunun işi yok; Raflar sekmesinde rafları grid view ile görelim;
    a rafındaki tüm kitapları b rafına aktarabilmeliyim."
    - **Favori yazarlar ana sayfada:** düzen asistanında seçilen favori
      yazarlar ana sayfanın "Favori yazarlar" şeridinde yıldız avatarlı
      kartlarla görünür; karta dokununca yazarın kitapları açılır.
      Kullanıcının kendi sırası korunur; kitabı olmayan favori yazar
      "Kitaplıkta yok" etiketiyle listede kalır. Favori seçilmediyse
      bölüm ipucu kartıyla yer tutar (bölümler kaymaz).
    - **Büyük harf davranışı:** manuel eklemede Kitap adı ve Yayınevi
      alanları artık yazar alanıyla aynı klavye davranışını alır
      (TextCapitalization.words: her boşluktan sonra büyük harf).
    - **Yazar önerileri:** yazar yazmaya başlayınca kitaplıkta daha önce
      geçmiş yazarlar küçük listede çıkar; Türkçe katlamayla eşleşir
      ("ahm" → "Ahmet Ümit", "ayse" → "Ayşe Kulin"). Öneri yalnız SON
      virgülden sonraki aktif yazım için üretilir; seçilen ad alana
      virgülle birlikte yazılır ve ikinci yazar hemen yazılabilir.
      Tam yazılmış yazar kendisi önerilmez.
    - **Yazarken çıkış onayı:** formda kaydedilmemiş giriş varken geri
      (uygulama çubuğu ya da sistem tuşu) engellenir ve "Çıkmak
      istediğinden emin misin?" diyaloğu çıkar: Vazgeç formda kalır,
      Çık yazılanları bırakır. Temiz formda soru sormadan açılır; yazılan
      geri alınırsa form yine temiz sayılır. Kaydet akışı diyaloğu
      atlayıp sayfayı güvenle kapatır.
    - **Ana sayfa uygulama çubuğu sadeleşti:** sırala/filtre aksiyonu
      ana sayfadan kaldırıldı (ana akış bölümleri sabit sırayla gelir;
      sıralamanın burada işi yok). Sıralama Raf sayfasındaki "Tüm
      kitaplar" listesinden yönetilmeye devam eder.
    - **Raflar sekmesi grid:** yatay kaydırmalı şerit yerine iki kolonlu
      grid; tüm raflar tek bakışta. Kart bilgisi aynıdır (ad, kitap
      sayısı, okunuyor/bitti kırılımı); 'Tüm kitaplar' ilk hücredir.
    - **Raf toplu taşıma:** somut raf sayfasında (ve 'Rafsız') "Bu
      raftaki tüm kitapları başka rafa taşı" aksiyonu eklendi: hedef
      raf seçilir (Rafsız ya da yeni raf da olabilir), kitaplar tek tek
      taşınır (okuma durumu/sayfa/günlük dokunulmaz). Hedef rafta yer
      yoksa kalınlık modeline göre hesap gösterilir ("3 birim taşar")
      ve kullanıcı yine de taşıyabilir. Kaynak raf tamamen boşalırsa
      Raflar sekmesine dönülür.

58. **Yazar asla bölünmez (raf düzeni)** — kullanıcı kuralı (1.17.0):
    "kesinlikle ama kesinlikle yazarlara göre talep edilmişse sırf favori
    rafa sığmıyor diye başka raflara yazarları bölme. Favori rafa 35
    kitap yazıldıysa ve yazarlar sığmıyorsa az olsun, 30 kitaba düşsün —
    ama yine de yazarları bölme."
    - **Yazara göre düzende her yazar ATOMİKTİR:** bir yazarın bütün
      kitapları ya tek raftadır ya da hiçbir rafa sığmıyorsa bütün
      halinde "Karışık kitaplar" rafındadır. "Sığan kadarı rafa, kalanı
      Karışık'a" bölmesi tamamen kaldırıldı; yer yetmediğinde raf eksik
      dolar (35'lik favori raf 30'da kalabilir), yazar ikiye asla
      bölünmez.
    - **Favori raf kuralı:** favori yazarların grupları favori rafa
      bütün halinde konur (kullanıcının sırasıyla); favori rafa sığmayan
      favori yazar bölünmez — grup tek parça olarak ilk sığan başka
      rafa gider, hiçbir rafa sığmıyorsa Karışık kitaplar rafına.
      Favori raf artık YALNIZCA favori yazarların kitaplarını tutar;
      kalan boşluk diğer kitaplara açılmaz ve önizlemede uyarıyla
      bildirilir (favori yazarların olası yeni kitapları için
      ayrılıdır).
    - **Kapsam:** bölme yasağı yalnız yazar kriteri ve favori
      yerleştirmededir; yayınevi kriteri eski davranışını sürer
      (taşan yayınevi grubu sığan kadarı rafa, artığı Karışık'a). Akış
      kriterlerinde (kitap adı / sayfa sayısı) favori yazarlar yine
      bütün gruplar halinde yerleşir; kitapların geri kalanı sırayla
      dizilir.
    - **Gerçek Karışık rafı yetmezse:** bütün yazar grubu Karışık
      rafına da sığmıyorsa kitaplar mevcut yerlerinde bırakılır ve plan
      dışı olduğu açıkça bildirilir (sessiz bölme yok).
    - Önizleme uyarıları yenilendi: hangi yazarın neden eksik dolu
      rafta ya da başka rafta olduğu, favori rafta ne kadar boşluk
      rezerve edildiği metin metin anlatılır.

59. **Ödünç verme ve ödünç alma (1.18.0)** — kullanıcı isteği: "bir
    kitabı ödünç verme sistemini ekleyelim. aynı zamanda bir kitabı da
    başkasından ödünç alma sistemini de getirelim."
    - **Ödünç verme:** kitap detayındaki "Ödünç ver" aksiyonu kişi adı
      (+isteğe bağlı not) ile kayıt açar (`loans_v1`); kitabın kendisi
      `books_v1` içinde yaşamaya devam eder, yalnız ödünç ilişkisi ayrı
      tutulur. Detay sayfası ödünçteyken kişi + tarih bannerı gösterir
      ve "Geri alındı" ile kayıt kapanır. Ana sayfada "Ödünç verilenler"
      bölümü, "Tümü" ile tam geçmiş sayfası (`/loans`: Sürüyor + Geri
      alınanlar).
    - **Ödünç alma:** başkasından aldığın kitaplar KİTAPLIK KAYDI
      DEĞİLDİR; `borrowed_v1` içinde bağımsız kayıt (başlık, yazar,
      sahip, not, tarih). "Ödünç aldıkların" sayfasında ekleyip
      düzenleyebilir, "Geri verdim" ile kapatabilirsin. Ana sayfada
      "Ödünç aldıkların" bölümü.
    - Kitap silinse bile ödünç geçmişi kitap adının kopyasıyla anlamlı
      kalır; bozuk kayıtlar savunmacı biçimde atlanır, yazmalar kilitli
      sıra ile yapılır.

60. **Open Library başlık/yazar araması + Satın alınacaklar (1.18.0)** —
    kullanıcı isteği: "kitap adı yada yazar a göre de arama varmıdır?
    eğer varsa hem kitap ekleme kısmına ekleyelim hemde satın alınacaklar
    listesi yapalım."
    - **Arama:** Open Library'nin `/search.json` ucu hem kitap adı hem
      yazar aramayı destekler; "Kitap ekle" menüsüne "İsim/yazarla ara"
      girdi eklendi. Sonuç kartında kapak, yazar(lar), ilk baskı yılı,
      yayınevi, sayfa sayısı görünür; her sonuç "Kitaplığa ekle"
      (formu doldurulmuş açar) ya da "Satın alma listesine ekle"
      verir.
    - **Satın alınacaklar:** `wishlist_v1` anahtarıyla ayrı liste.
      Open Library aramasından ya da "Elle ekle" diyaloğundan beslenir;
      kartta kaynak rozeti ('Open Library' / 'Manuel') vardır. "Kitaplığa
      ekle" formu doldurulmuş açar; düzenleme dokunuşla, çıkarma onaylı
      çöp ikonuyla. Ana sayfada "Satın alınacaklar" bölümü.
    - Aynı ISBN (ya da başlık+yazar) listede iki kez oluşamaz; arama
      boş girişte çalışmaz, ağ hataları Türkçe mesajla bildirilir.

61. **Günlük okuma hatırlatıcısı (1.18.0)** — kullanıcı isteği: "flutter
    local notification paketiyle de okumaya başladığı ve günlük kaç sayfa
    okuyacağını bildiren bir sistem kuralım ve kullanıcı saat kaçta
    bildirim gelmesini istiyorsa o saatte bildirim gelsin ve ayarlar
    kısmından da bildirimleri katabilsin."
    - **flutter_local_notifications + flutter_timezone + timezone**
      paketleri eklendi. Ayarlar sekmesinde "Okuma hatırlatıcısı"
      bölümü: anahtar (varsayılan KAPALI), saat seçici (varsayılan
      20:30), günlük sayfa hedefi (varsayılan 20, 1-1000 arası).
    - Açıkken her gün seçilen saatte yerel bildirim gelir: "Bugün
      N sayfa okuma hedefin var. İyi okumalar!" Zamanlama cihaz yerel
      saat diliminde günlük tekrarlıdır (inexact alarm; izin isteme
      Android 13+ POST_NOTIFICATIONS, iOS alert/sound ile yapılır).
    - Ayarlardan kapatınca alarm iptal edilir; uygulama güncellenip
      alarm sıfırlansa bile açılışta yeniden kurulur (BOOT_COMPLETED
      alıcısı da manifest'te bildirildi). Tercih anahtarları:
      `settings_reminder_enabled/hour/minute/pages`.

62. **cm tabanlı raf kapasitesi; kriterler bağımsız; düzenleyicide numara
    (1.19.0)** — kullanıcı kararı: "420 sayfalık kitap kalınlığı 3 cm, 130
    sayfalık 1 cm; favori raf ve favori yazarlar yalnız yazara göre
    seçiliyken görünsün ve devreye girsin; yayınevine, kitap adına, sayfa
    sayısına göre kendi başlarına çalışsın; raf düzenleyicide sol tarafta
    1 2 3 4 sıralaması olsun; rafların uzunluğunu cm olarak sor".
    - **cm modeli:** raf kapasitesi artık kullanıcının girdiği
      **uzunluk (cm)**'dur (`shelves_v1`'e `lengthCm` alanı eklendi;
      eski `capacity` alanı uyumluluk için yine yazılır, eski veri
      `kapasite × 2,5 cm` ile otomatik cm'ye taşınır). Kitabın kapladığı
      yer sayfa sayısından hesaplanır: **420 sayfa ≈ 3 cm, 130 sayfa
      ≈ 1 cm** (mm ≈ (300 + 20 × sayfa) / 290); sayfası bilinmeyen kitap
      2,5 cm sayılır. Planlama milimetre tam sayılarıyla yapılır.
    - **Anahtar kalktı:** 'Kalın kitaplar daha çok yer kaplar' anahtarı
      kaldırıldı — hesap daima cm'dir; `settings_thickness_aware`
      anahtarı donmuş listede kalır ama okunmaz/yazılmaz. Doluluk
      metinleri '38 kitap • 96,4/125 cm' biçimindedir.
    - **Kriter bağımsızlığı:** favori raf + favori yazarlar YALNIZ
      "Yazara göre" kriterinde görünür ve devreye girer; kurulum
      sayfasında kart sırası Raflar → Kriter → (Favoriler) → Onay oldu.
      Yayınevi / kitap adı / sayfa sayısı düzenlemeleri favorilerden
      tamamen bağımsızdır (planlayıcı + UI + tanı uyarıları birlikte
      kapıdan geçer).
    - **Düzenleyici:** her raf kartının solunda düzen sıra numarası (1,
      2, 3…) vardır — plan 1. raftan başlar; hızlı kurulum ve raf
      diyaloğu cm ister ('Her raf kaç cm?' / 'Uzunluk (cm)').
    - **Dürüst çıktı:** önizleme kartları numaralıdır; özet kartı ve alt
      açıklama planın RAF İÇİ dizilişi kapsamadığını açıkça yazar
      ("plan yalnız raf atamalarını taşır") — "yalnız 1 kitap taşınacak"
      çıktısının ne anlama geldiği tek bakışta bellidir.

## Sürüm notları

**1.19.3:** `pubspec.yaml` sürümü `1.19.3+27`'e yükseltildi. Kullanıcı
raporu (iki ekran görüntüsü): "Yazara göre" düzenlemede çıkan sonuç
güncellemeden sonra da değişmiyordu; kullanıcının teşhisi doğruydu —
sorun raf adlarının eşleşmemesiydi. Kök neden: "Raflar" sekmesi
kitaplara YAZILI raf adlarını gösterir ('Koridor Raf 1', 'Tv Üzeri'…);
"Rafları düzenle" ekranı ise düzen asistanının tanımlarını
('Koridor 1', 'Tv uzeri'…). Raf ataması ad bazlıdır ve düzen planı
yalnız TANIMLI rafları kullanır: adlar birebir aynı değilse tanım
kartlarında doluluk 0 görünür, plan kitapları tanım adlarına dağıtır
ve çıktı gerçek kitaplıkla tutmaz. Yalnız 'Tv uzeri' ≡ 'Tv Üzeri'
Türkçe katlaması (aksan/büyük harf duyarsız) eşleştiği için tek kart
50 kitabıyla dolu görünüyordu; öbür beşi boştu. Güncellemelerin
sonucu değiştirmemesi de doğrudu: 1.19.1 yalnız ödünç sıralamasını,
1.19.2 yalnız plan sayfasındaki kapsam uyarısını düzeltmişti. Düzeltme
iki katmanlı: (1) KULLANICIYA — tanım adlarını kitaplardaki adlarla
birebir aynı yapmak yeterlidir (kalem simgesi → ad; yeniden adlandırma
yalnız eski ada bağlı kitapları taşır, kitaplar zaten gerçek
adlarındayken güvenlidir); (2) UYGULAMAYA — kitaplarda olup tanımı
olmayan adlar artık görünmez değil: düzenleyicide en üstte uyarı kartı
listeler, kurulum sayfasının hazırlık kartında hata satırı uyarır,
raf ekleme/düzenleme diyaloğu bu adları tek dokunuşla doldurulabilir
öneri çipi olarak sunar ve ad alanı artık "kitapların raf kaydı bu
adla yapılır" yardımı taşır. Yeni `unmatchedBookShelfNames()` yardımcısı
uyarı kartlarının ve önerilerin tek kaynağıdır (katlama ile
aynılaştırır, farklı yazımları tek madde yapar). Veri anahtarları
(`shelves_v1`, `organize_plan_v1`, `books_v1`) ve saklanan veriler
değişmedi. Yeni testler: eşleşme yardımcısının beş durumu + düzenleyici
uyarı kartı/öneri çipi/kapanış akışı + kurulum uyarısı (toplamda 710
test yeşil, `flutter analyze`: No issues found!).

**1.19.2:** `pubspec.yaml` sürümü `1.19.2+26`'a yükseltildi. Kullanıcı
raporu (ekran görüntüsü): "Yazara göre" düzenlemede plan 1 kitap
taşıyordu ve plan sayfasında "268 kitap plan yapıldıktan sonra
eklendi" uyarısı çıkıyordu — sanki kitaplığın gerisi plan dışı
kalmıştı. Kök neden: "sonradan eklenen kitaplar" hesabı, planın
TAŞINAN kitap kimlikleriyle karşılaştırılıyordu; taşınmayan her kitap
(kütüphanenin tamamına yakın) yanlışlıkla "sonra eklenmiş" sayılıyordu.
Oysa düzen planı kütüphanenin tamamını kapsar: taşınmayanlar planın
hedefinde zaten kendi raftalarındadır. Düzeltme: plan modeline kapsama
kümesi eklendi (`coveredBookIds` — plan üretildiğindeki tüm kitaplar;
`organize_plan_v1` anahtarı değişmedi, eski kayıtlar aynen okunur),
"sonradan eklenen" hesabı artık kapsama kümesiyle yapılır; kapsama
kümesi olmayan eski planlarda eklenme tarihine dönülür (taşınmayanlar
orada da dışarıda sayılmaz). Plan sayfasında dışarıda kitap yokken
artık dürüst kapsam kartı çıkar: "Plan kitaplığın tamamını kapsıyor;
taşınmayan kitaplar planın hedefinde zaten kendi raftalarındadır…" —
"Toplam 1 kitap taşınacak" çıktısının "düzenleme bozuk" sanılmasının
önüne geçildi (kütüphane çoğunlukla hedef düzendeysen az taşınma
DOĞRU sonuçtur). Yeni testler: kapsama kümesi JSON turu + tur
işaretlemede korunma, eski biçem kayıt okuma, taşınmayanlar-dışarıda-
değil regresyonu, kapsam/dışarı kartları; toplam 700 test yeşil
(`flutter analyze`: No issues found!).

**1.19.1:** `pubspec.yaml` sürümü `1.19.1+25`'e yükseltildi. Kullanıcı
raporu: Windows'ta `loan_controller_test.dart` içindeki "activeBorrowed
en yeni alımdan başlar" testi `['Eski', 'Yeni']` dönüyordu. Kök neden
test hatası değil, platform farkıydı: Windows'ta saat çözünürlüğü kaba
(~15 ms tık) olduğundan art arda iki `addBorrowed` çağrısı aynı
`DateTime.now()` değerini alabiliyor; tarihler eşitlenince Dart'ın
kararlı sıralaması ekleme sırasını koruyor ve liste en eskiden
başlıyordu (Linux'ta mikrosaniye çözünürlük olduğundan gözden
kaçmıştı). Düzeltme iki katmanlı: (1) denetleyicideki dört sıralama
getter'ına (`activeLoans`, `returnedLoans`, `activeBorrowed`,
`returnedBorrowed`) eşitlik kırıcı eklendi — tarihler aynıysa
listedeki konumu büyük (son eklenen) kayıt önce gösterilir; gösterim
sırası artık eşit tarihlerde bile platformdan bağımsız ve
deterministiktir; (2) ilgili testin saat bağımlılığı belgelenip
yeniden yazıldı ve üç deterministik regresyon testi eklendi (depodan
yüklemede ayrık tarihli alıntı sırası, eşit tarihli alıntı sırası,
eşit verilme tarihli ödünç sırası). Veri anahtarları ve saklanan
veriler değişmedi; davranış farkı yalnızca eşit tarihli kayıtların
gösterim sırasındadır. Toplam 694 test yeşil (`flutter analyze`: No
issues found!).

**1.19.0:** `pubspec.yaml` sürümü `1.19.0+24`'e yükseltildi. Veri
anahtarları değişmedi; `shelves_v1` içindeki raf kayıtlarına **geriye
dönük uyumlu** bir alan eklendi (`lengthCm`): eski kayıtlı raflar
`kapasite × 2,5 cm` ile otomatik cm'ye taşınır, eski JSON
(`capacity`-only) aynen okunur ve `capacity` alanı yine yazılır.
`settings_thickness_aware` anahtarı listede kalır ama artık
okunmaz/yazılmaz (anahtar kalktı). Yeni ölçek kullanıcı ölçümleriyle
kalibre edildi: 420 sayfa ≈ 3 cm, 130 sayfa ≈ 1 cm; bilinmeyen sayfa
≈ 2,5 cm. Kullanıcı kararları: (1) favori raf/favori yazarlar yalnız
"Yazara göre" kriterinde görünür ve devreye girer, öteki üç kriter
kendi başına çalışır; (2) raf düzenleyicide her rafın solunda düzen
sıra numarası (1, 2, 3…) gösterilir; (3) "raf içi diziliş rehberi"
eklenmedi — yerine önizleme özeti ve açıklamalar planın kapsamını
açıkça yazar. Raf düzenleme hattının tüm testleri yeni modele
taşındı; yeni testler: eski veri → cm geçişi (50 kitap → 125 cm),
kalınlık formülü (420→30 mm, 130→10 mm, 0→25 mm), favorilerin
yayınevi kriterinde yok sayılması, cm doluluk metinleri, koşullu
favoriler kartı, numaralı düzenleyici/önizleme; toplam 691 test yeşil
(`flutter analyze`: No issues found!).

**1.18.1:** `pubspec.yaml` sürümü `1.18.1+23`'e yükseltildi. Kullanıcı
raporu: "rafları düzenle butonuna basıyor ama ya uygulama kilitleniyor
ya da sadece 1 kitap değiştirme çıkıyor." İki ayrı kök neden bulundu ve
giderildi; veri anahtarları ve plan formatı (`organize_plan_v1`)
değişmedi, plan algoritmasının çıktısı birebir korundu.

- **Kilitlenme (ANR):** taşıma planı üretimi kuadratikti — her tur
  adımında tüm bekleyen hareketler baştan taranıyor, yer etiketi her
  hareket için raf tanımlarını yeniden okuyordu. 3000 kitapta ölçüm:
  5.3 saniye kesintisiz ana izolasyon bloğu (Android ANR eşiği ~5 sn);
  1.18.1'de aynı girdi 0,2 saniyenin altında (raf-adı kuyrukları +
  yer-etiketi önbelleği; ~25 kat hızlanma). Yeni uygulama, ESKİ
  uygulamanın gömülü referans kopyasıyla tur tur emir emir
  karşılaştırılarak doğrulandı (`move_plan_builder_equivalence_test`):
  tek yer/çok yer/rafsız/harf varyantı/çift kayıt senaryolarında
  planlar birebir aynı. Plan sayfasında 24 emri aşan turlar artık sabit
  yükseklikte kaydırılabilir listede tembel kurulur; büyük tur
  kartının açılışı donduruyordu.
- **"Sadece 1 kitap değiştirme":** kitaplık çoğunlukla hedef düzendeysen
  plan DOĞRU olarak 0-1 hamle üretir (önceki plan tamamlandıysa ya da
  tek yeni kitap geldiyse). Çıktı artık kendi kendini açıklar:
  önizlemenin üstünde özet kartı ("N kitap taşınacak, M kitap zaten
  hedef düzeninde"); taşınacak hiçbir şey yoksa önizleme sayfası
  silinmiyor, snackbar ile kalıyor. Sessiz no-op kökleri de açıklandı:
  (a) favori raf tercihi kayıtlı ama raf artık yoksa (hızlı kurulum
  rafları yeniden açınca kimlikler yenilenir) favori yerleştirme
  sessizce atlanıyordu — kurulum sayfası ve önizleme uyarısı ekledi;
  (b) favori yazar adı kitaplık verisiyle yazım farkıyla eşleşmiyorsa
  planlayıcı boş grubu sessizce atlıyordu — önizlemede hangi
  yazarların eşleşmediği yazılıyor. Raf adlarını kitaplardan içe
  aktarırken aksan/büyük harf duyarsız tekilleştirme eklendi
  ('Kitaplık' + 'kitaplık' tek raf). Yeni testler: eşdeğerlik +
  başarım, favori tanılama uyarıları, no-op planın önizlemeyi
  koruması, önizleme özet kartı, yetim favori raf ipucu, büyük tur
  tembel kurulumu, içe aktarma tekilleştirmesi; toplam 693 test yeşil.

**1.18.0:** `pubspec.yaml` sürümü `1.18.0+22`'ye yükseltildi. Mevcut
veri anahtarları (`books_v1`, `shelves_v1`, `organize_plan_v1`) hiç
değişmedi; üç yeni anahtar eklendi (`loans_v1`, `borrowed_v1`,
`wishlist_v1`) ve dört yeni tercih anahtarı (`settings_reminder_*`).
Yedek zarfı **formatVersion 2**'ye çıktı: ödünç verilenler, ödünç
alınanlar ve satın alma listesi artık yedekte taşınır — "üzerine yaz"
içe aktarmada bu kayıtlar da komple değişir, "birleştir"de kimlik/ISBN/
başlık+yazar eşleşenler atlanır. Sürüm 1 dosyaları hâlâ okunur (yeni
bloklar boş gelir); eski uygulama sürümü 2 dosyayı anlamlı hatayla
reddeder. Yeni paketler: `flutter_local_notifications`,
`flutter_timezone`, `timezone`. Yeni testler: ödünç modeli/depo/
denetleyici/sayfalar/detay bannerı, Open Library arama (MockClient ile
URL ve savunmacı ayrıştırma), satın alma modeli/depo/denetleyici/
sayfalar, hatırlatıcı servis/denetleyici/bölüm, yedek v2 blokları
(uçtan uca taşıma, sürüm 1 uyumu, bozuk kayıt reddi, depoların
opsiyonelliği); toplam 665 test yeşil.

**1.17.0:** `pubspec.yaml` sürümü `1.17.0+21`'e yükseltildi. Veri
anahtarları (`books_v1`, `shelves_v1`, `organize_plan_v1`) ve tercih
anahtarları değişmedi; yeni anahtar eklenmedi. Davranış değişikliği:
yazara göre düzende ve favori yerleştirmede yazar grupları artık asla
iki rafa bölünmez — taşan yazar bütün halinde başka rafa ya da Karışık
kitaplar rafına gider; favori raf yalnızca favori yazarların
kitaplarını tutar ve gerekirse eksik dolar. Yayınevi kriterinin
taşan-grup davranışı değişmedi. Plan çıktısı değiştiği için sürüyor
olan taşıma planlarında "Yeniden planla" kullanılması önerilir.
Planner testleri yeni kurallara göre genişletildi (kullanıcı örneği:
35'lik favori raf 30'da kalır, yazar bölünmez); toplam 516 test yeşil.

**1.16.0:** `pubspec.yaml` sürümü `1.16.0+20`'ye yükseltildi. Veri
anahtarları (`books_v1`, `shelves_v1`, `organize_plan_v1`) ve mevcut
tercih anahtarları değişmedi; yeni anahtar eklenmedi — favori yazarlar
1.15.0'daki `settings_favorite_authors` anahtarından okunur. Form
kapatma davranışı değişti: kirli formda geri tuşu artık onay diyaloğu
açar (Kaydet bu diyaloğu atlar). Yeni testler: favori yazar özet servisi
ve ana sayfa bölümü, büyük harf ipuçları, yazar otomatik tamamlama
(virgül sonrası aktif yazım dahil), çıkış onayı (temiz/kirli/Vazgeç/
Çık/Kaydet yolları), Raflar grid yerleşimi ve raf toplu taşıma
(sığan/taşan/vazgeçilen hedefler); 1.15.0'daki 482 testin tamamı
korundu.

**1.15.0:** `pubspec.yaml` sürümü `1.15.0+19`'a yükseltildi. Kitaplık
verisi ve mevcut anahtarlar (`books_v1`, `shelves_v1`,
`organize_plan_v1`) değişmedi; üç yeni tercih anahtarı eklendi
(`settings_favorite_shelf_id`, `settings_favorite_authors`,
`settings_thickness_aware`) — yedek zarfı bunları taşımaz, tercihler
cihazın kullanıcısına aittir. Kalınlık hesabı varsayılan AÇIK gelir:
aynı raf artık kalın kitaplarda daha az kitap alır (istediysen anahtarla
eski kitap sayısı davranışına dönersin). Favoriler yarım seçilirse
(yalnız raf ya da yalnız yazar) plan klasik kriterle çalışır. Plan
üretimi aynı girdiden aynı sonucu verir (kararlılık testleri korundu).
Yeni testler: kalınlık tablosu, birim bazlı grup/akış/Karışık rafı,
favori yerleştirme sırası, sığmayan favori kitabın kaybolmadan
dağıtılması, yarım tercih/bilinmeyen raf savunmaları, kalıcılık ve
kurulum/önizleme ekran akışları; toplam 482 test.

**1.14.0:** `pubspec.yaml` sürümü `1.14.0+18`'e yükseltildi. Veri
anahtarları (`books_v1`, `shelves_v1`, `organize_plan_v1`) ve biçimleri
değişmedi: mevcut kullanıcılar kitaplıklarını kaybetmez. Yeni paketler:
`share_plus` (sistem paylaşım menüsü — WhatsApp dahil) ve `file_picker`
(yedek dosyası seçimi; tür filtresi bilinçli olarak serbest, doğrulama
içerik üzerinden). Yedek zarfı (`kitapligim-yedek`, formatVersion 1)
yalnız kitap + raf verisi taşır; taşıma planı ve tercihler cihazda
kalır. "Üzerine yaz" eski taşıma planını sıfırlar; "Birleştir" plana
dokunmaz (yeni kitaplar için "Yeniden planla" önerilir). Yeni testler:
yedek zarfı ayrıştırma/ret, birleştirme/üzerine yazma kuralları, toplu
yazma (addMany/replaceAll) ve denetleyici + ayarlar ekranı akışları;
toplam 445 test.

**1.13.0:** `pubspec.yaml` sürümü `1.13.0+17`'ye yükseltildi. Kitaplık verisi
(`books_v1`) değişmedi: mevcut kullanıcılar kitaplıklarını kaybetmez.
İki yeni anahtar eklendi: `shelves_v1` (raf tanımları: ad, kapasite,
yer, sıra) ve `organize_plan_v1` (sürüyor olan taşıma planı; plan
bitince/iptal edilince silinir). Bozuk kayıtlar açılışta savunmacı
biçimde atlanır; bilinmeyen kriterli plan geçersiz sayılır.

Raf düzeni asistanı tamamen kullanıcı kararıyla çalışır: grup modunda
aynı yazar/yayınevi tek rafta birleşir ve yazarlar kitap sayısı çoktan
azaya dizilir; en büyük raf kapasitesini aşan grubun artığı 'Karışık
kitaplar' rafına gider. Akış modunda kitaplar kütüphane gibi dizilir.
Taşıma planı evdeki işi emir emir anlatır: aynı kat tek turda, rafta
önce çıkanlar alınır, tek elde en fazla 10 kitap taşınır. Ayarlar
sayfasındaki sürüm satırı pubspec ile eşitlenerek 1.13.0'a getirildi
(önceki sürümlerde 1.6.0'da kalmıştı). Okuma günlüğü (`readingLog`)
eski kayıtlarda boş gelir ve ilk kayıttan itibaren derlenmeye başlar;
ana sayfa bölümleri mevcut alanlardan (`addedAt`, `targetFinishDate`,
`authors`, `shelf`, `finishedAt`) hesaplanır. "Bu ay bitirdiklerin"
bölümü bitiş tarihi bilinen kayıtları sayar; bitiş tarihi girilmemiş
eski kayıtlar bölüm ipucu kartıyla karşılanır.

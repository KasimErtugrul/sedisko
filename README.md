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

## Sürüm notları

`pubspec.yaml` sürümü `1.10.0+14`'e yükseltildi. Depolama anahtarları
(`books_v1` ve `settings_*`) değişmedi: mevcut kullanıcılar kitaplıklarını
kaybetmez; okuma günlüğü alanı (`readingLog`) eski kayıtlarda boş gelir ve
ilk kayıttan itibaren derlenmeye başlar; `isFavorite` eski kayıtlarda
`false` gelir; `coverPath` ve bitirme hedefi (`targetFinishDate`) eski
kayıtlarda boş gelir. Bu sürümde veri modeli değişmedi: ana sayfa
bölümleri mevcut alanlardan (`addedAt`, `targetFinishDate`, `authors`,
`shelf`, `finishedAt`) hesaplanır. Raf taşıma, favori çevrimi ve yazar adı
birleştirmesi günlük türetmez; yalnız okuma durumu/sayfa değişimleri
günlüğe yazar. Sıralama tercihi oturum içindedir; uygulama her açılışta
kitap adı artan varsayılanıyla başlar. "Bu ay bitirdiklerin" bölümü bitiş
tarihi bilinen kayıtları sayar; bitiş tarihi girilmemiş eski kayıtlar bu
bölümde görünmez (yanlış ayda göstermek yerine).

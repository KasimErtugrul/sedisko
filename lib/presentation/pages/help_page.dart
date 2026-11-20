import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';

/// Keşke 2 (1.26.0): 'Uygulama nasıl kullanılır?' sayfası.
///
/// Hasan'ın notu: "Takıldığım her yerde deneme yanılma ile ilerledim.
/// Ayarlar'da bile uygulamanın nasıl kullanılacağına dair bir açıklama
/// yok." Sayfa günlük dilde, yol yol anlatır: kitap ekleme, raflar,
/// otomatik düzenleme, okuma takibi, ödünç, satın alma listesi, yedek ve
/// terslik anında yapılacak. Statik içeriktir: denetleyicisi, servisi,
/// depolama anahtarı yoktur; metinler bu dosyada yaşar.
///
/// Giriş yolları: Ayarlar'daki 'Uygulama nasıl kullanılır?' satırı ve
/// boş kitaplık ekranındaki 'Nasıl kullanılır?' düğmesi.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _sections = <_HelpSection>[
    _HelpSection(
      key: 'help-first-book',
      title: 'İlk kitabını ekle',
      paragraphs: [
        'Ana sayfada sağ alttaki "Kitap ekle" düğmesine dokun. Üç yol '
        'çıkar:',
        '1. Barkod tara — kitabın arkasındaki ISBN etiketini okutur, '
        'bilgileri internetten getirir.\n'
            '2. İnternette ara — kitabın adını ya da yazarını Open '
            'Library\'de arar; bulduğunu "Kitaplığa ekle" ile alırsın.\n'
            '3. Kendim yazacağım — adı ve rafı yazıp Kaydet\'e basarsın; '
        'gerisi isteğe bağlıdır.',
      ],
    ),
    _HelpSection(
      key: 'help-shelves',
      title: 'Raflarını hazırla',
      paragraphs: [
        'Raflar sekmesindeki "Raf tanımları" düğmesine dokun. Buradan raf '
        'eklersin: ad (örn. "Salon - 2. raf"), kaç cm kitap tuttuğu ve '
        'nerede olduğu ("Alt kat" gibi).',
        'Raf adları kitapların üzerinde yazılı adla aynı olursa düzenleme '
        'asistanı doğru çalışır; ad uyuşmazsa uygulama seni uyarır ve tek '
        'dokunuşla düzeltmeni önerir.',
      ],
    ),
    _HelpSection(
      key: 'help-organize',
      title: 'Kitapları otomatik diz',
      paragraphs: [
        'Raflar sekmesindeki "Rafları otomatik düzenle" düğmesi adım adım '
        'sorar: rafların hazırlığı, kitaplar neye göre dizilsin, favori '
        'yazarlar (isteğe bağlı). Eksik adım varsa "Planı oluştur" düğmesi '
        'altında neyi unuttuğun yazar.',
        'Plan hazır olunca "Plan önizlemesi"nde hangi kitabın nereye '
        'gideceğini görürsün. "Planı uygula" ile geziler başlar; rafı '
        'doldurunca "Yaptım"e dokunursun. Yarıda bırakırsan ana sayfadaki '
        'kart sana hatırlatır.',
      ],
    ),
    _HelpSection(
      key: 'help-move',
      title: 'Kitabı yanlış rafa koydum',
      paragraphs: [
        'Kitap kartında "Başka rafa taşı" düğmesi var; detay sayfasında '
        '"Raf" satırına dokununca da raf seçilir. Kitaplığın tamamını '
        '"Raflar sekmesi > Tüm kitaplar"dan açıp tek tek taşıyabilirsin.',
        'Rafın ADINI değiştirmek istersen "Raf tanımları"ndaki kalem '
        'simgesini kullan; eski adla bağlı kitaplar yeni adı otomatik alır.',
      ],
    ),
    _HelpSection(
      key: 'help-reading',
      title: 'Okuma takibi',
      paragraphs: [
        'Kitap detayında "Sayfayı güncelle" sana "Kaçıncı sayfadasın?" '
        'diye sorar; +1 / +10 düğmeleriyle yazmadan ilerleyebilirsin. '
        '"Bitirdim" kitabı bitirir; "Yeniden oku" sıfırdan başlar.',
        'Her gün belirli saatte hatırlatma istersen Ayarlar > Günlük okuma '
        'hatırlatıcısı anahtarını aç; sayfa hedefini de oradan seçersin.',
      ],
    ),
    _HelpSection(
      key: 'help-loans',
      title: 'Ödünç ver / al',
      paragraphs: [
        'Kitabı birine vermek için detaydaki "Ödünç ver"e dokun: kimin '
        'aldığını yazarsın, istersen iade günü seçersin (+1 hafta çipi '
        'gibi). O gün gelince uygulama haber verir; kitap gelince "Geri '
        'alındı" dersin.',
        'Başkasından aldığın kitaplar için "Ödünç aldıkların" sayfası '
        'var; oradan kayıt açınca "sahibine geri ver" gününü de '
        'seçebilirsin.',
      ],
    ),
    _HelpSection(
      key: 'help-wishlist',
      title: 'Satın alacakların',
      paragraphs: [
        '"Kitap ekle > İnternette ara" ile bulduğun kitabı "Satın alma '
        'listesine ekle" ile kaydedersin; kitabı aldığında listedeki '
        '"Aldım" düğmesine dokunursun.',
        'Listedeki kitabı kitaplığa eklersen kayıt seni beklemeyi '
        'bırakır; artık gerçek bir kitap olarak rafta sayılır.',
      ],
    ),
    _HelpSection(
      key: 'help-backup',
      title: 'Yedek',
      paragraphs: [
        'Ayarlar > "Yedeği paylaş" bütün kitaplığını tek dosyaya yazar: '
        'kitaplar, raf tanımları, ödünç kayıtları ve satın alma listesi. '
        'Dosyayı WhatsApp\'tan eşine ya da kendine gönderebilirsin.',
        'Yeni cihazda "Yedeği geri yükle" ile açarsın: birleştir (mevcut '
        'veriyi koruyup ekler) ya da üzerine yaz (bütün değiştirir; ikinci '
        'bir onay sorar) seçilir.',
      ],
    ),
    _HelpSection(
      key: 'help-trouble',
      title: 'Bir terslik olursa',
      paragraphs: [
        'Yanlışlıkla kitap sildysen bildirimdeki "Geri Al" düğmesi '
        'kitabı aynı raf, aynı okuma durumuyla geri koyar.',
        'Bir hata balonu çıkarsa ne yapacağını yazar ("İşlemi yeniden '
        'dene; sürerse uygulamayı kapatıp aç."). Verinin değişmediği '
        'durumlarda bu ayrıca söylenir.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Uygulama nasıl kullanılır?')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'Kısaca yol yol: kitap ekleme, raflar, otomatik düzenleme, '
              'okuma takibi, ödünç, yedek. Takıldığın yerin başlığına dokun.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final section in _sections)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              clipBehavior: Clip.antiAlias,
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: ValueKey(section.key),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(section.title),
                  children: [
                    for (final paragraph in section.paragraphs)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(paragraph),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tek yardım başlığı; başlık + kısa paragraflar.
class _HelpSection {
  const _HelpSection({
    required this.key,
    required this.title,
    required this.paragraphs,
  });

  /// Test bulgusu için sabit kimlik ('help-first-book' gibi).
  final String key;
  final String title;
  final List<String> paragraphs;
}

/// Ayarlar sayfasından ve boş kitaplıktan açılan giriş yardımcısı:
/// rotaya yalnız isimle gidilir; çağıran dosya Routes.help'i kullanır.
void openHelp() => Get.toNamed(Routes.help);

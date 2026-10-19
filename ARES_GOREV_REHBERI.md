# ARES Görev Rehberi

Bu dosya, ARES'e (sesli asistanınıza) yeni komutları nasıl ekleyeceğinizi anlatır.

## ARES nasıl çalışır?

1. **Uyandırma:** İki kez arka arkaya el çırpın (yaklaşık 1,5 saniye içinde). ARES,
   "Merhaba İbrahim, senin için ne yapabilirim?" diyerek karşılık verir.
   - Alkış algılanmazsa (gürültülü ortam, mikrofon hassasiyeti vb.) ekranın ortasındaki
     büyük göz/hexagon simgesine dokunarak da ARES'i elle uyandırabilirsiniz.
2. **Komut:** ARES konuştuktan hemen sonra sizi ~6 saniye dinler (ekranda "Dinliyorum..."
   yazısı çıkar). Bu süre içinde komutunuzu söyleyin.
3. **Yanıt:** ARES, kaydettiği sesi Google Gemini API'sine gönderip yazıya çevirir,
   komutu anlarsa gereken işlemi yapar (kategori açar, uygulama açar, internette arar)
   ve sesli olarak kısa bir onay verir.

## Gemini API anahtarını ayarlama (ilk kurulumda gerekli!)

ARES, söylediklerinizi yazıya çevirmek için Google'ın Gemini yapay zekasını kullanıyor.
Bunun için ücretsiz bir API anahtarına ihtiyaç var:

1. Tablette (veya bilgisayarda) `https://aistudio.google.com/apikey` adresine gidin,
   Google hesabınızla giriş yapıp "Create API key" ile ücretsiz bir anahtar oluşturun.
2. Uygulamayı açın → sağ alt köşedeki **AYARLAR** butonuna basın.
3. **Google Gemini API Anahtarı** alanına anahtarınızı yapıştırın.
4. İsterseniz OpenAI, Claude, Grok, GitHub Token gibi diğer API anahtarlarını da ekleyin.
5. **KAYDET** butonuna basın.

Artık ARES bir sonraki uyandırmada yeni anahtarları kullanır.
Dosya yöneticisiyle uğraşmanıza gerek yok.

Ayrıca Ayarlar'dan:
- Dinleme süresini (3–12 saniye)
- Alkış hassasiyetini (düşük / orta / yüksek)
- Asistan ve sahip adını
değiştirebilirsiniz.

**Not:** Gemini'nin ücretsiz katmanı günlük belirli bir kullanım sınırına sahiptir;
normal ev kullanımı için fazlasıyla yeterlidir.

## Görev dosyası nerede?

ARES, komutlarını **`ares_gorevler.json`** adlı bir dosyadan okur. Bu dosya, tabletin
şu konumunda saklanır:

```
Android/data/com.destos.ares/files/ares_gorevler.json
```

Bu dosyaya tabletteki herhangi bir **dosya yöneticisi** uygulamasıyla (örn. "Dosyalarım",
"Files by Google") ulaşıp, bir **metin düzenleyici** ile (örn. "Text Editor", "QuickEdit")
açıp düzenleyebilirsiniz.

**Önemli:** Dosya, uygulama ilk açıldığında otomatik olarak oluşturulur (projedeki
varsayılan `assets/ares_tasks.json` dosyasının bir kopyasıdır). Yani önce uygulamayı
bir kere açıp kapatmanız, sonra dosya yöneticisiyle yukarıdaki konuma gitmeniz gerekir.

Dosyayı değiştirdikten sonra **uygulamayı yeniden kurmanıza gerek yoktur** — ARES her
uyandığında dosyayı yeniden okur, değişiklikleriniz bir sonraki alkışta devreye girer.

## Yeni komut nasıl eklenir?

Dosyanın içinde `"gorevler"` adında bir liste vardır. Her komut şöyle bir blok:

```json
{
  "tur": "tam_eslesme",
  "eylem": "kategori_ac",
  "parametre": "SOSYAL",
  "tetikleyiciler": ["sosyal aç", "sosyal kategorisini aç"],
  "yanit": "Sosyal kategorisini açıyorum."
}
```

Yeni bir blok eklemek için, listedeki son `}`'den sonra bir virgül koyup yeni blok
eklemeniz yeterli. Alanların anlamı:

| Alan | Açıklama |
|---|---|
| `tur` | `"tam_eslesme"` (söylediğiniz cümlenin İÇİNDE bu kelime/cümle geçiyorsa tetiklenir) veya `"onek"` (cümle bu kelimeyle BAŞLIYORSA tetiklenir, geri kalanı parametre olarak kullanılır) |
| `eylem` | Ne yapılacağı — aşağıdaki 4 seçenekten biri |
| `parametre` | Sadece `kategori_ac` için: açılacak kategorinin adı |
| `tetikleyiciler` | Bu komutu tetikleyecek kelime/cümlelerin listesi |
| `yanit` | ARES'in sesli söyleyeceği cevap. `%s` yazarsanız, söylediğiniz değişken kısım oraya yerleşir |

### Kullanabileceğiniz 4 eylem türü

1. **`kategori_ac`** — Belirli bir kategoriyi açar.
   `parametre` alanına şu isimlerden birini yazın: `SOSYAL`, `ARES`, `MEDYA`,
   `ARAÇLAR`, `İŞ`, `SİSTEM`, `İNTERNET`, `DİĞER`.

2. **`uygulama_ac`** — Söylenen ismi kurulu uygulamalar arasında arayıp açar.
   `tur` mutlaka `"onek"` olmalı, çünkü uygulama adı komuttan sonra gelir. Örnek:
   ```json
   {
     "tur": "onek",
     "eylem": "uygulama_ac",
     "tetikleyiciler": ["aç ", "başlat "],
     "yanit": "%s açılıyor."
   }
   ```
   Bu örnekte "YouTube aç" dediğinizde ARES "YouTube" kelimesini uygulama listesinde arar.

3. **`internette_ara`** — Söylenen konuyu Google'da aratıp tarayıcıda açar.
   Yine `tur: "onek"` olmalı. Örnek: "hava durumu nasıl olacak hakkında bilgi ver".

4. **`soyle`** — Sadece sabit bir cevap söyler, başka bir şey yapmaz. Basit soru-cevaplar
   eklemek için idealdir (örn. "günaydın" → "Günaydın İbrahim, harika bir gün seni
   bekliyor").

### Örnek: Yeni bir basit komut ekleme

Diyelim "ışıkları aç" dediğinizde ARES size sadece "Işıklar şu an bağlı değil ama
yakında olacak" desin istiyorsunuz. `gorevler` listesinin sonuna şunu ekleyin:

```json
,
{
  "tur": "tam_eslesme",
  "eylem": "soyle",
  "tetikleyiciler": ["ışıkları aç", "işikları aç"],
  "yanit": "Işıklar şu an bağlı değil ama yakında olacak."
}
```

**Dikkat:** JSON formatı hataya duyarlıdır — her `{` bir `}` ile, her `[` bir `]` ile
kapanmalı, bloklar arasına virgül (`,`) konmalı (son bloktan sonra virgül OLMAMALI).
Dosyayı kaydettikten sonra ARES'i uyandırıp yeni komutu deneyin; eğer JSON bozulmuşsa
ARES sessizce varsayılan görevlere döner (uygulama çökmez).

## Sınırlamalar (şu an neler YAPILAMAZ)

- Bu dosyayla sadece yukarıdaki 4 hazır eylem türü için **yeni tetikleyici cümleler**
  ekleyebilirsiniz. Tamamen yeni bir eylem türü (örn. "alarm kur", "mesaj gönder")
  eklemek kod değişikliği gerektirir — böyle bir ihtiyacınız olursa bana söyleyin.
- İnternet araması, sonuçları uygulama içinde listelemez; tarayıcıyı arama sonuçlarıyla
  açar (API anahtarı gerektirmeyen, güvenilir yöntem budur).
- Ses tanıma artık Gemini API üzerinden çalıştığı için **internet bağlantısı zorunludur**
  (tabletin Wi-Fi'si kapalıyken ARES komutları tanıyamaz, ama alkışla uyanıp
  "Gemini API anahtarı ayarlanmamış" gibi hataları hâlâ sesli söyler).
- Şu anki dinleme süresi sabit ~6 saniyedir; çok uzun cümlelerin sonu kesilebilir.
  Gerekirse bu süreyi `ares_service.dart` içinde birlikte uzatabiliriz.

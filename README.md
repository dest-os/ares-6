# DEST-OS ARES Launcher

Futuristik Android tarzı launcher uygulaması + ARES sesli asistan.

## ÖNEMLİ - Nasıl Kullanılır? (Kod bilmeyenler için)

### 1. Gemini API Anahtarı (ARES için zorunlu)

1. Tablette veya bilgisayarda şu adrese git:  
   **https://aistudio.google.com/apikey**
2. Google hesabınla giriş yap → **Create API key**
3. Anahtarı kopyala
4. Uygulamayı aç → sağ altta **AYARLAR** butonuna bas
5. **Google Gemini API Anahtarı** alanına yapıştır → **KAYDET**

Artık ARES çalışmaya hazır!

### 2. Alkış ile uyandırma

- **İki kez** art arda el çırp (yaklaşık 1–1,5 saniye içinde)
- ARES: "Merhaba İbrahim, senin için ne yapabilirim?" der
- Komutunu söyle (ör. "sosyal aç", "YouTube aç", "hava durumu ara")

Alkış çalışmazsa ekranın ortasındaki **büyük göz / hexagon** simgesine dokun.

Ayarlar'dan alkış hassasiyetini (düşük / orta / yüksek) değiştirebilirsin.

### 3. Birden fazla API anahtarı

Ayarlar ekranından şunları ekleyebilirsin:
- Google Gemini (zorunlu – ses tanıma)
- OpenAI
- Claude (Anthropic)
- Grok (xAI)
- OpenWeatherMap
- GitHub Token + kullanıcı adı + depo adı
- Özel API anahtarı + base URL

Tüm anahtarlar sadece senin cihazında saklanır.

### 4. Bilgisayarda çalıştırmak

```
cd tablet-main
flutter pub get
flutter run
```

### 5. GitHub ile APK almak

1. GitHub'da yeni depo oluştur
2. Bu klasörün tüm dosyalarını yükle
3. Actions sekmesinden "Build APK" işinin bitmesini bekle
4. APK'yı indir ve tablete yükle

## Özellikler

- Canlı saat ve tarih
- Canlı takvim
- Gerçek hava durumu (konum + Open-Meteo)
- 8 kategori butonu + kısayol ekleme
- ARES sesli asistan (alkış veya dokunma ile)
- Ayarlar paneli (çoklu API anahtarı)
- Dinleme süresi ve alkış hassasiyeti ayarı
- Neon mavi siberpunk tasarım

## Notlar

- Gerçek Android uygulamalarını açmak için installed_apps kullanılır.
- Launcher olarak kullanmak istersen sistem ayarlarından varsayılan ana ekran olarak seç.
- ARES görevlerini ares_gorevler.json dosyasından (cihazdaki ARES klasörü) düzenleyebilirsin.

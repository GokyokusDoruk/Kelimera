# Kelimera — Tasarım Belgesi

Tarih: 2026-11-23 · Durum: onay bekliyor

Bu belge, Kelimera'yı planlayıp geliştirecek birinin oyun sahibine geri dönmeden çalışabilmesi için yazıldı. **[Karar: sahip]** işaretli maddeler oyun sahibinin verdiği kararlardır. **[Öneri]** işaretli maddeler tasarımcının önerileridir; geliştirme sırasında ve testlerde değiştirilebilirler.

---

## 1. Amaç

Kelimera, aynı ortamda bulunan 2-4 arkadaşın internet olmadan, telefonlarını Bluetooth ile birbirine bağlayarak oynadığı Türkçe bir kelime oyunudur. Oyuncular ortak bir tahtaya harf dizerek kelime kurar. Oyunun ruhu "masa başı" oyunu: herkes yan yana oturuyor, sırayla oynuyor, beklerken sohbet ediyor.

Oyunu değerli kılan üç şey var:
- İnternet ve hesap gerektirmeden, yan yana oturan insanlar arasında oynanıyor.
- iOS ve Android telefonlar aynı oyunda buluşabiliyor.
- Sözlüğü tamamen projeye ait. Lisanslı hiçbir kaynak kullanılmıyor.

## 2. Hedefler, kapsam dışı olanlar, kaçınılacaklar

**Hedefler**
- 2-4 oyuncu, iOS ve Android karışık, yalnızca BLE ile çalışan bir oyun.
- Bir oyun yaklaşık 10-15 dakika sürmeli.
- Kurallar oyun sırasında anlaşılır olmalı: oyuncu hamlesini göndermeden önce hangi kelimelerin oluştuğunu, geçerli olup olmadıklarını ve kaç puan getireceklerini görebilmeli.
- Kendi Türkçe sözlüğü olmalı ve oynandıkça büyüyebilmeli.

**İlk sürümde olmayacaklar**
- İnternet üzerinden oyun, hesap ya da sunucu.
- Bilgisayar rakibe (bot) karşı oynama. Testlerde kullanılan botlar oyunda yer almayacak.
- Hakem telefon koparsa hakemliğin başka telefona devredilmesi.
- Liderlik tablosu, istatistik, satın alma, reklam.
- Türkçe dışında bir dil.

**Kaçınılacaklar.** Teknik olarak çalışsa bile aşağıdakilerden biri olursa proje başarısız sayılır:
- Lisanslı içerik kullanılması. Bu sözlüğü, sıklık verisini, görselleri ve sesleri kapsar.
- Oyunun görünüşünün Scrabble'a ya da Kelimelik'e benzemesi: aynı renkler, aynı çarpan dizilimi, aynı taş tasarımı ya da aynı isim.
- Bir oyuncunun başkasının elindeki harfleri görebilmesi ya da kendi puanını değiştirebilmesi.
- Tek bir oyuncunun bağlantısı koptuğunda bütün oyunun kilitlenmesi.

## 3. Kısıtlar

- **Platform:** iOS ve Android **[Karar: sahip]**.
- **Bağlantı:** Yalnızca Bluetooth Low Energy kullanılacak. Klasik Bluetooth iOS'ta üçüncü parti uygulamalara kapalı. Apple Multipeer ile Google Nearby ise birbirleriyle konuşamıyor. Bu yüzden iki platformu birbirine bağlayabilen tek ortak yol BLE.
- **Hakem telefon:** Odayı kuran telefon BLE "peripheral" rolünde çalışacak, yani GATT sunucusu olacak. Uygulama bu telefonda oyun boyunca ön planda kalmalı. iOS'ta arka plana geçen uygulamanın reklam yayını kısıtlanıyor.
- **Lisanslı içerik yok [Karar: sahip]:** Sözlük, harf sıklıkları, harf puanları, avatarlar ve sesler ya projede üretilecek ya da AlphaRing'in projeye özgü içeriğinden gelecek.
- **Geliştirme ortamı:** Windows. Şu an bu bilgisayarda Flutter, Dart, Android SDK ve JDK kurulu değil, plan bunları kurmakla başlamalı. iOS derlemesi için bir Mac ve Apple Developer hesabı ya da Codemagic gibi bir bulut derleme servisi gerekiyor. Gerçek BLE testi için en az bir iPhone ve bir Android telefon şart.

## 4. Değerlendirilen yaklaşımlar

| Yaklaşım | Artı | Eksi |
|---|---|---|
| **Flutter ✅ seçildi** | Tek kod tabanı. Tahta çizimi ve sürükle bırak için güçlü. Central tarafında `flutter_blue_plus` olgun. Oyun mantığı saf Dart olarak yazılıp kolayca test edilebiliyor. | Peripheral rolü için hazır paket (`ble_peripheral`) orta olgunlukta. Yetersiz kalırsa platform başına ince bir native katman yazılacak. |
| React Native | JS ekosistemi, AlphaRing'deki deneyim | Peripheral desteği daha zayıf. Yine native modül gerekiyor. |
| Swift ve Kotlin ayrı ayrı | BLE üzerinde tam kontrol | Arayüz dahil her şey iki kez yazılır. |
| Telefonlardan biri hotspot açar, oyun yerel ağ üzerinden oynanır | Hızlı ve kolay | Kullanıcıya hotspot açtırmak zahmetli, iOS'ta kısıtlı. Oyunun "Bluetooth ile yan yana" fikrine de uymuyor. |

Flutter, tasarımcının önerisiydi ve oyun sahibi itiraz etmedi.

---

## 5. Oyun kuralları

### 5.1 Oyuncular ve sıra
- 2-4 oyuncu **[Karar: sahip]**. Oda kurulduktan sonra en az 2 kişi olunca oyunu kuran "Başlat"a basar.
- Oyuncular aynı anda değil, sırayla oynar. Sırası olmayanlar tahtayı izler ve sohbet eder.
- Oturma sırası oyun başında rastgele belirlenir ve herkese gösterilir **[Öneri]**.
- **Büyük tur:** Her oyuncu bir kez hamle yapar. Oyun 5 büyük turda biter **[Karar: sahip]**, yani 4 kişide 20, 2 kişide 10 hamle oynanır.

### 5.2 Tahta
- 11x11 kare **[Karar: sahip]**.
- Oyun başında sözlükten rastgele bir "başlangıç kelimesi" seçilir ve tahtanın ortasındaki satıra (6. satır) yatay olarak, ortalanmış şekilde yerleştirilir **[Karar: sahip]**. Bu kelime 5-7 harfli ve zorluk derecesi 1-3 olan kelimeler arasından seçilir. Kimseye puan kazandırmaz ve oyunda "kullanılmış kelime" sayılır **[Öneri]**. Kelimenin harf sayısı çiftse tam ortalanamaz; bu durumda bir kare sola kaydırılır, örneğin 6 harfli bir kelime 3-8. sütunlara yerleşir.
- Çarpanlar **[Öneri]**. Tahtanın deseni ve çarpan türleri projeye özgü. Desen yatay, dikey ve çapraz eksenlerde simetrik:
  - **H2 / H3:** Üstüne konan harfin puanını 2 ya da 3 katına çıkarır.
  - **K2 / K3 / K4:** Harflerden biri bu kareye konursa bütün kelimenin puanını 2, 3 ya da 4 katına çıkarır.
  - Bir çarpan yalnızca harfin tahtaya konduğu hamlede işler. Sonraki hamlelerde etkisi yoktur.

```
     1   2   3   4   5   6   7   8   9  10  11
 1  K4  .   .   H3  .   K3  .   H3  .   .   K4
 2  .   K2  .   .   .   .   .   .   .   K2  .
 3  .   .   .   .   H2  .   H2  .   .   .   .
 4  H3  .   .   K2  .   .   .   K2  .   .   H3
 5  .   .   H2  .   H2  .   H2  .   H2  .   .
 6  K3  .   .   .   .   ★   .   .   .   .   K3     ← başlangıç kelimesi bu satırda
 7  .   .   H2  .   H2  .   H2  .   H2  .   .
 8  H3  .   .   K2  .   .   .   K2  .   .   H3
 9  .   .   .   .   H2  .   H2  .   .   .   .
10  .   K2  .   .   .   .   .   .   .   K2  .
11  K4  .   .   H3  .   K3  .   H3  .   .   K4
```
Toplamda 4 adet K4, 4 adet K3, 8 adet K2, 8 adet H3 ve 12 adet H2 var. Başlangıç kelimesinin oturacağı satırın ortasında çarpan bulunmuyor. Desen, ilk denemelerden sonra ayarlanabilir.

### 5.3 Harfler, el ve joker
- **Alfabe:** Türk alfabesinin 29 harfi kullanılır: A B C Ç D E F G Ğ H I İ J K L M N O Ö P R S Ş T U Ü V Y Z. Bunlara ek olarak joker vardır.
- **El:** Her oyuncunun elinde 8 harf bulunur **[Karar: sahip]**. Ellerin içeriği oyuncudan oyuncuya farklıdır ve rastgele dağıtılır **[Öneri, sahip itiraz etmedi]**.
- **Harf çekme:** Harfler sınırsız bir havuzdan, ağırlıklı rastgele seçimle çekilir. Torba diye bir şey yoktur ve hiç bitmez **[Karar: sahip]**. Her harfin çekilme ağırlığı, kendi sözlüğümüzde o harfin ne sıklıkla geçtiğine göre hesaplanır. Bu hesabı sözlük derleme betiği yapar.
- **El garantisi:** Her elde en az 2 sesli harf (A E I İ O Ö U Ü) ve en az 3 sessiz harf bulunur **[Karar: sahip]**. El tamamlanırken bu koşul sağlanmıyorsa yeni çekilen harfler eksik olan gruptan seçilir. Joker, hangi grupta eksik varsa o gruptan sayılır **[Öneri]**.
- **Joker:** Her çekilişte yaklaşık %2 ihtimalle çıkar **[Karar: sahip]**. Oyuncu jokeri tahtaya koyarken hangi harfin yerine geçeceğini seçer. Jokerin harf puanı 0'dır. Bu yüzden harf çarpanından etkilenmez, ama bulunduğu kelimeye kelime çarpanı uygulanır.
- **Harf puanları [Öneri]:** Harf puanları kendi sözlüğümüzdeki harf sıklığından türetilir: harf ne kadar seyrekse puanı o kadar yüksektir. Sözlük büyüdükçe yeniden hesaplanır. Başlangıç tablosu şöyle:

| Puan | Harfler |
|---|---|
| 1 | A E İ N R L K |
| 2 | I D M T S Y U |
| 3 | B O Ü Ş Z |
| 4 | G Ç H |
| 5 | C Ğ V P |
| 7 | Ö F |
| 10 | J |

### 5.4 Hamle
- Her hamle için **45 saniye** süre vardır **[Karar: sahip]**. Süre ilk testlerde gözden geçirilecek.
- Sırası gelen oyuncu iki şeyden birini yapar:
  1. **Kelime koymak:** Kullandığı harfler elinden gider ve eli yeniden 8 harfe tamamlanır **[Karar: sahip]**.
  2. **8 harfin hepsini yenilemek:** Elindeki bütün harfler yenileriyle değişir. Oyuncu bu turda puan alamaz **[Karar: sahip]**.
- **Süre dolarsa** oyuncunun turu boş geçer ve eli değişmez **[Karar: sahip]**.
- **Reddedilen hamle:** Hamle geçersizse oyuncuya nedeni gösterilir. Eli değişmez, süresi işlemeye devam eder ve süre bitene kadar yeni bir deneme yapabilir **[Karar: sahip]**.
- **Süre sınırındaki hamleler:** Hamle hakem telefona son saniyeden sonra en fazla 500 ms gecikmeyle ulaşırsa kabul edilir. Bu pay BLE'nin gecikmesini karşılamak için var **[Öneri]**.

### 5.5 Yerleştirme kuralları
- Bir hamlede en az bir harf konmalı ve harfler yalnızca boş karelere konabilir.
- Bir hamlede konan bütün harfler aynı satırda ya da aynı sütunda olmalıdır.
- Konan harfler arasında boşluk kalmamalıdır. Aradaki boşluklar ancak tahtada zaten bulunan harflerle dolabilir.
- Hamle tahtadaki mevcut harflere bağlanmalıdır. Yani ya bir mevcut harfi kelimenin içinde kullanmalı ya da bir mevcut harfin yanına değmelidir **[Karar: sahip]**.
- **Yan kelimeler, Scrabble kuralı [Karar: sahip]:** Bir hamlede oluşan bütün kelimeler kontrol edilir. Bunlar ana kelime ve konan her harfin dik yönde oluşturduğu 2 ya da daha fazla harfli kelimedir. Hamlenin geçerli olması için bu kelimelerin hepsinin sözlükte bulunması gerekir. Her biri ayrı ayrı puan getirir.
- **En kısa kelime 2 harftir [Karar: sahip].**
- **Tekrar yasağı:** Bir kelime oyun boyunca bir kez yazılabilir. Önceden kim yazmış olursa olsun aynı kelime tekrar yazılamaz **[Karar: sahip]**. Bu yasak yalnızca **ana kelimeye** uygulanır. Yan kelimeler, örneğin kısa bir "AT", tekrar oluşabilir. Aksi halde tahta birkaç turda kilitlenir **[Öneri]**.
- **Tek harfli hamleler:** Oyuncu tek bir harf koyarsa ana kelime, o harfin oluşturduğu daha uzun kelime sayılır. İki yönde de oluşan kelime eşit uzunluktaysa yatay olan ana kelimedir **[Öneri]**.

### 5.6 Puanlama
Bir hamlenin puanı aşağıdaki gibi hesaplanır:

```
hamle puanı = Σ (oluşan her kelime için kelime puanı)  +  ana kelimenin taban puanı  +  8 harf bonusu

kelime puanı = ( Σ harf puanı × harf çarpanı )  ×  kelime çarpanlarının çarpımı
taban puan   = uzunluk puanı + nadirlik puanı
```

- **Çarpanlar:** Yalnızca bu hamlede konan harflerin altındaki karelerin çarpanları işler. Bir kelime iki kelime çarpanından geçerse çarpanlar birbiriyle çarpılır, örneğin K2 ile K3 birlikte ×6 eder.
- **Taban puan:** "Uzun ve nadir kelime daha değerli" ilkesini karşılar **[Karar: sahip]**. Yalnızca ana kelimeye verilir **[Öneri]**.
  - **Uzunluk puanı [Öneri]:** `max(0, uzunluk − 3) × 2`
  - **Nadirlik puanı [Öneri]:** Sözlükteki zorluk derecesine göre verilir.

    | Zorluk derecesi | 1 | 2 | 3 | 4 | 5 |
    |---|---|---|---|---|---|
    | Nadirlik puanı | 0 | 2 | 4 | 7 | 10 |
- **8 harf bonusu:** Elindeki 8 harfin hepsini tek hamlede kullanan oyuncu +40 puan alır **[Karar: sahip]**.
- Bütün sayılar, test oyunlarından sonra yeniden ayarlanabilir.

### 5.7 Bitiş
- Oyun, 5. büyük turun son hamlesinden sonra biter. En yüksek puanı alan oyuncu kazanır.
- **Beraberlik:** Puanlar eşitse kazanan, oyun içinde tek hamlede en yüksek puanı almış olan oyuncudur. O da eşitse oyuncular berabere kalır **[Öneri]**.
- **Oyundan çıkanlar:** Oyundan ayrılmış sayılan oyuncular sonuç tablosunda "ayrıldı" etiketiyle görünür ama kazanan olamazlar **[Öneri]**.

### 5.8 İtiraz ve öneri
Bu bölümün tamamı **[Karar: sahip]**.
- Bir hamle "sözlükte yok" gerekçesiyle reddedilirse, oyuncu o kelimeyi "Oylamaya sun" düğmesiyle oylamaya sunabilir.
- Diğer oyuncular 15 saniye içinde Evet ya da Hayır oyu verir. Oylama oyunu durdurmaz, oyuncunun süresi işlemeye devam eder **[Öneri]**.
- Oylama kelimeyi o oyunda geçerli yapmaz. Çoğunluk "Evet" derse kelime, hakem telefondaki **öneri listesine** eklenir.
- Öneri listesi uygulamanın içindeki bir ekranda görülebilir ve "Paylaş" düğmesiyle (WhatsApp, e-posta vb.) metin olarak gönderilebilir **[Öneri]**. Kelimenin sözlüğe girip girmeyeceğine oyun sahibi karar verir. Onaylanan kelimeler bir sonraki sürümle sözlüğe eklenir.

### 5.9 Profil, sohbet
- **Profil:** Oyuncu ilk açılışta bir ad yazar (en fazla 16 karakter) ve hazır avatarlardan birini seçer **[Karar: sahip]**. İlk sürümde projeye özgü 16 avatar olur. Fotoğraf yükleme özelliği yoktur, BLE üzerinden yalnızca avatarın numarası gönderilir **[Öneri]**. Profil telefonda kayıtlı kalır.
- **Sohbet:** Herkese açık, yalnızca metin. Bir mesaj en fazla 120 karakter olabilir **[Karar: sahip, uzunluk öneri]**. Sohbet oyun ekranında bir alt panel olarak açılır. Okunmamış mesaj varsa bir rozet görünür.

### 5.10 Bağlantı kopması
Bu bölümün tamamı **[Karar: sahip]**.
- **Oyun başladıktan sonra odaya yeni oyuncu katılamaz.** Yalnızca daha önce oyunda olan oyuncular geri bağlanabilir **[Öneri]**.
- **Bir oyuncu koparsa:** Oyun devam eder. Sırası gelirse 45 saniye beklenmez, turu hemen boş geçilir **[Öneri]**. 2 dakika içinde geri bağlanırsa aynı eli ve aynı puanıyla devam eder. Dönmezse "ayrıldı" sayılır ve oyun onsuz sürer. Oyunda 1 kişi kalırsa oyun biter.
- **Hakem koparsa:** Oyun duraklar ve herkes 2 dakika hakemi bekler. Hakem dönerse oyun kaldığı yerden sürer. Hakem telefon oyunun durumunu her değişiklikte diske yazdığı için uygulaması kapanmış olsa bile oyun kaybolmaz. Hakem dönmezse oyun o anki puanlarla biter.

---

## 6. Ekranlar

Akış: **Profil** (yalnızca ilk açılışta) → **Ana ekran** (Oda kur / Odaya katıl / Öneri listesi / Profil) → **Lobi** → **Oyun** → **Sonuç**

- **Oda kur:** Odayı kuran telefonda 4 haneli bir oda kodu ve katılan oyuncuların avatarları görünür. En az 2 kişi olunca "Başlat" düğmesi açılır.
- **Odaya katıl:** Yakındaki odalar listelenir. Her satırda odayı kuranın adı, avatarı ve oda kodu bulunur. Oyuncu odaya dokunarak katılır.

Oyun ekranının taslağı:

```
┌───────────────────────────────┐
│ 🐱Ayşe 42  🦊Can 37  🐼Ece 18 │  ← skor şeridi, sırası gelen oyuncu vurgulu
│ Tur 3/5        ⏱ 0:27         │
│ ┌───────────────────────────┐ │
│ │                           │ │
│ │       11×11 tahta         │ │
│ │                           │ │
│ └───────────────────────────┘ │
│ KALEMLİK ✓ +24   AT ✓ +3      │  ← canlı önizleme: oluşan kelimeler, geçerli mi, puanı
│ [K][A][L][E][M][İ][★][T]      │  ← el (★ = joker)
│ [Geri al] [Karıştır] [8'i yenile] [GÖNDER] │
│                        💬 2   │
└───────────────────────────────┘
```

- **Harf yerleştirme:** Harfler sürüklenerek ya da önce harfe sonra kareye dokunarak yerleştirilebilir. "Geri al" düğmesi tahtaya konan harfleri ele döndürür.
- **Canlı önizleme:** Oyuncunun kendi telefonundaki sözlükle hesaplanır. Kesin karar yine hakem telefonundadır.
- **8'i yenile:** Yanlışlıkla basılmasın diye önce onay ister.

---

## 7. Mimari

### 7.1 Depo yapısı [Öneri]
```
Kelimera/
  packages/game_core/   saf Dart: kurallar, tahta, puan, harf çekme, sözlük arama, oyun durumu
  packages/net_core/    saf Dart: mesaj protokolü, hakem mantığı, istemci oturumu,
                        Transport arayüzü ve test için FakeTransport
  app/                  Flutter uygulaması: arayüz, BLE taşıyıcıları, kalıcı kayıt
  dictionary/           sözlük kaynağı (TSV), öneri listeleri
  tool/                 Dart betikleri: sözlük derleme, kontrol, harf sıklığı ve puan üretimi
  docs/
```
`game_core` ve `net_core` Flutter'a ve ağa bağımlı değildir. Bu sayede 4 oyunculu bir maç, telefon kullanılmadan baştan sona testte simüle edilebilir.

### 7.2 Hakem modeli
- **Tek doğru kaynak hakemdir.** Odayı kuran telefon hakemdir ve oyunun tek doğru durumunu o tutar. Harf çekme, hamle doğrulama, puanlama, süre takibi, tur ilerletme ve oylama hakemde yapılır.
- **Hakemin sahibi de sıradan bir istemcidir.** Hakem telefonu kullanan oyuncu, hakeme diğerleri gibi bir istemci olarak bağlanır. Aradaki tek fark, bağlantının BLE yerine uygulama içinde çalışan bir taşıyıcı üzerinden kurulmasıdır.
- **Durum tam olarak gönderilir.** Durum değiştiğinde hakem her oyuncuya ayrı bir **tam durum özeti** gönderir. Özette tahta, puanlar, sıra, tur, kalan süre, oyuncuların bağlantı durumları, kullanılmış kelimeler ve **sadece o oyuncunun kendi eli** bulunur. Kimse başkasının elini göremez.
- **Yeniden bağlanma kendiliğinden çözülür.** Geri bağlanan oyuncu son özeti alır ve oyuna devam eder.
- **Hakem durumu diske yazar.** Her değişiklikte durumu JSON olarak kaydeder. Uygulama yeniden açıldığında "Yarım kalan oyunu sürdür" seçeneği sunulur.

### 7.3 Protokol [Öneri]
- **Mesaj tipleri:**
  - `HELLO`: oyuncu kimliği, ad, avatar, uygulama sürümü
  - `WELCOME` / `REJECT`: oda dolu, oyun başlamış ya da sürüm uyumsuz
  - `LOBBY`
  - `STATE`
  - `MOVE`: harf yerleşimleri ve jokerin hangi harf olduğu
  - `SWAP_ALL`
  - `MOVE_RESULT`: kabul ya da ret, ret nedenleri ve kazanılan puan
  - `VOTE_START`, `VOTE`, `VOTE_RESULT`
  - `CHAT`
  - `PING` / `PONG`
- **Biçim:** Mesajlar UTF-8 JSON olarak gönderilir. Her mesajın bir sürüm alanı ve bir mesaj numarası vardır.
- **Sürüm uyumu:** Protokol sürümü farklı olan bir telefon odaya alınmaz (`REJECT`). Sözlük sürümünün farklı olmasına izin verilir: canlı önizleme oyuncunun kendi sözlüğüyle yapılır ama hakemin kararı geçerlidir.
- **Oyuncu kimliği:** İlk açılışta üretilen rastgele bir UUID'dir ve telefonda saklanır. Geri bağlanan oyuncu bu kimlikle tanınır.
- **Süre:** Hakem kalan süreyi milisaniye cinsinden gönderir, istemciler bu değeri yerel saatleriyle geri sayar.

### 7.4 BLE katmanı [Öneri]
- **GATT yapısı:** Projeye özgü bir servis UUID'si ve iki karakteristik kullanılır:
  - `client→host`: yanıtlı yazma
  - `host→client`: bildirim. Hakem her istemciye yalnızca ona ait bildirimleri gönderir. iOS'ta bunu `updateValue(onSubscribedCentrals:)`, Android'de cihaz bazında `notifyCharacteristicChanged` sağlar.
- **Parçalama:** BLE paketleri küçük olduğu için mesajlar parçalanıp karşı tarafta birleştirilir. Her parçanın başlığında mesaj numarası, parça sırası ve toplam parça sayısı bulunur. Android'de MTU 185-512 bayta yükseltilmeye çalışılır, iOS bunu kendisi ayarlar.
- **Reklam yayını:** Servis UUID'si ve kısa bir ad yayınlanır, örneğin `KLM-4821` biçiminde oda kodu. iOS'ta reklam paketine sığan veri çok az olduğu için kuranın adı ve avatarı bağlantıdan sonra `LOBBY` mesajıyla gelir.
- **Kütüphaneler:**
  - Central rolü için `flutter_blue_plus`.
  - Peripheral rolü için önce `ble_peripheral` denenir. Plan aşamasında olgunluğu bir deneme projesiyle sınanacak. Yetersiz kalırsa Swift'te CoreBluetooth `CBPeripheralManager`, Kotlin'de `BluetoothGattServer` ve `BluetoothLeAdvertiser` ile ince bir platform kanalı yazılır.
- **İzinler:** Android 12 ve sonrasında `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` ve `BLUETOOTH_ADVERTISE`. iOS'ta `NSBluetoothAlwaysUsageDescription`.

### 7.5 Arayüz [Öneri]
- Durum yönetimi için Riverpod kullanılır.
- Tahta özel çizilir (`CustomPaint` ya da widget ızgarası).
- Renkler, taş tasarımı ve ikon projeye özgüdür. Ayrıntılı görsel tasarım planın ilgili adımında hazırlanacak.

---

## 8. Sözlük

Bu bölüm sözlüğün kuralları, kaynağı, nasıl genişleyeceği, biçimi ve kontrolleriyle ilgili.

### 8.1 Kurallar
Bu kuralların tamamı **[Karar: sahip]**.
- **Sözlük bütünüyle projeye aittir.** TDK, Zemberek, sıklık listeleri ya da herhangi bir lisanslı kaynak kullanılmaz.
- **Çekimli halleri geçersizdir.** Kök kelimeler ve yapım ekiyle türemiş sözlük maddeleri geçerlidir: KALEM ve KALEMLİK geçerli, KALEMLER ve KALEMİ geçersiz.
- **Fiillerde hem mastar hem kök geçerlidir:** GELMEK ve GEL. Kökler sözlüğe ayrıca yazılmaz, derleme betiği mastardaki -mak/-mek ekini silerek kökleri kendisi üretir.

### 8.2 Kaynak
- **Çekirdek:** AlphaRing projesinin kendi içeriğinden gelen 2.588 tekil Türkçe kelime. Bu kelimeler `apps/api/src/seed/turkishPool.json` ve `scripts/content/tr-*.txt` dosyalarında duruyor. Çoğunluğu isim: yaklaşık 2.020 isim, 351 fiil, 215 sıfat. AlphaRing'deki "kolay", "orta" ve "zor" etiketleri sırasıyla 2, 3 ve 4 zorluk derecesine çevrilir **[Öneri]**.

### 8.3 Genişletme
- Sözlük, harf harf ve konu konu (mutfak, doğa, meslekler, duygular vb.) kelime ekleyerek genişletilir. Eklenen kelimeler hiçbir sözlükten kopyalanmaz. Her kelimeye tür ve 1-5 arası bir zorluk derecesi verilir **[Karar: sahip]**.
- **Hedef:** İlk sürüm için 20-30 bin kök kelime **[Öneri]**.
- **Zorluk derecesi:** 1 en yaygın, 5 en nadir anlamına gelir. Değeri, kelimeyi ekleyen kişinin değerlendirmesiyle verilir. Dış bir sıklık verisi kullanılmaz.

### 8.4 Biçim
- **Kaynak dosya:** `dictionary/kelimeler.tsv`. Her satırda dört alan bulunur: `kelime`, `tür`, `zorluk`, `kaynak`. `kaynak` alanı `alpharing` ya da `kelimera` değerini alır.
- **Derleme çıktısı:** Derleme betiği uygulamanın içine gömülecek bir varlık dosyası üretir. Bu dosyada büyük harfe çevrilmiş kelimeler, zorluk dereceleri ve fiil kökleri bulunur. Aynı betik harf sıklığı ve harf puanı tablosunu da üretir.
- **Büyük harfe çevirme:** Türkçe kurala göre yapılır: i → İ, ı → I. Ç, Ğ, Ö, Ş ve Ü korunur. Şapkalı harfler şapkasız karşılıklarına çevrilir, örneğin â → A.
- **Bellekte tutma:** Sözlük uygulama açılırken belleğe bir `Set<String>` olarak yüklenir. 30 bin kelime civarında bu yeterince hızlıdır.

### 8.5 Kontrol betiği
Her eklemede çalışır ve şunları denetler:
- tekrar eden kayıtlar
- alfabe dışı karakterler
- 2 harften kısa kelimeler
- geçersiz zorluk değeri ya da tür
- çekim eki şüphesi taşıyan kelimeler (-lar/-ler, -ı/-i/-u/-ü, -dı/-di/-tı/-ti, -yor vb.). Bu bir hata değil, uyarıdır ve elle onay gerektirir.

---

## 9. Test

- **`game_core` testleri:** Test önce yazılır. Kapsam: yerleştirme kuralları, yan kelime bulma, puanlama, çarpanlar, joker, el garantisi, tekrar yasağı, tur ve süre durumları.
- **`net_core` testleri:** `FakeTransport` ile 2-4 oyunculu maçlar baştan sona simüle edilir. Kopma ve geri bağlanma, hakemin yeniden başlaması, süre sınırındaki hamleler ve hiçbir oyuncuya başkasının elinin gitmediği ayrıca test edilir.
- **Bot ile uzun deneme:** Rastgele hamle yapan botlarla binlerce oyun oynatılır ve hiçbir kuralın bozulmadığı doğrulanır. Örneğin el her zaman 8 harf olmalı ve puan hiçbir zaman eksiye düşmemeli.
- **Sözlük testleri:** Derleme betiğinin çıktısı ve Türkçe büyük harf dönüşümü test edilir.
- **Gerçek cihaz testi:** Elle yapılır. En az şu senaryolar denenir: iPhone hakem + Android istemci, Android hakem + iPhone istemci, 4 cihazlı oda, bir istemcinin uzaklaşıp geri gelmesi, hakem uygulamasının kapatılıp yeniden açılması.

## 10. Plan aşamasına bırakılanlar

- Flutter SDK, Android SDK ve JDK'nın kurulumu, iOS derleme yolunun seçimi (Mac mi, Codemagic mi).
- Paket sürümlerinin belirlenmesi ve `ble_peripheral` paketinin bir deneme projesiyle sınanması.
- Görsel tasarım: renkler, taşlar, ikon, avatar çizimleri, sesler.
- Sözlüğün hangi sırayla genişletileceği. Oyun hemen sözlük çekirdeğiyle denenebilir.
- Uygulama mağazası adının kontrolü: "Kelimera" adıyla App Store ve Google Play'de çakışma var mı, TÜRKPATENT'te tescilli bir marka var mı.

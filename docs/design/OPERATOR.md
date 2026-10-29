# Stitch operatörü talimatı (paralel çalışma)

Bu dosya, Google Stitch'te istem paketlerini (docs/design/NN-*.md) üreten operatör ajanların ortak kurallarıdır. Tarayıcı tek ve kullanıcı oturumu AÇIK; birden çok operatör AYNI ANDA kendi sekmesinde ve kendi Stitch projesinde çalışır.

## Araçlar
`ToolSearch` ile yükle: `select:mcp__playwright__browser_navigate,mcp__playwright__browser_run_code_unsafe,mcp__playwright__browser_take_screenshot,mcp__playwright__browser_tabs,mcp__playwright__browser_wait_for`.
Giriş/parola isteme, Google hesabına giriş yapmaya çalışma. Oturum düşmüşse DUR ve raporla. Paylaşma/yayınlama (Share) YAPMA.

## Sekme kuralı (ÇOK ÖNEMLİ: paralel çalışma)
`browser_navigate`, `browser_take_screenshot`, `browser_tabs select` MCP'nin "geçerli sekmesini" kullanır; BAŞKA operatörlerle çakışır. Bu yüzden:
- Her işi `browser_run_code_unsafe` ile yap ve HER çağrının başında kendi sekmeni adresindeki proje kimliğiyle bul:
  ```js
  async (page) => {
    const p = page.context().pages().find(x => x.url().includes('PROJE_KIMLIGI'));
    await p.bringToFront();
    // ... p ile işlem
  }
  ```
- Ekran görüntüsünü de run_code içinde `await p.screenshot({ path: 'C:/bu_design/_tmp/<ad>.png' })` ile al ve Read ile oku (browser_take_screenshot KULLANMA).
- İlk sekmeyi açmak için: `const p = await page.context().newPage(); await p.goto('https://stitch.withgoogle.com/'); ` (browser_navigate KULLANMA; başka operatörün sekmesini bozar).
- Çağrılar kısa olsun (bekleme döngüleri en çok ~60 sn); uzun beklemeyi birden çok çağrıya böl; her çağrıda bringToFront.
- Başka sekmeleri KAPATMA/kullanma.

## Stitch arayüzü (denenmiş)
- Stitch arayüzü bir iframe içinde: `p.frames().find(f => f.url().includes('appspot.com'))`. İstem kutusu: o frame içinde `[contenteditable="true"], textarea` ilk eleman. `await box.click(); await p.keyboard.insertText(METIN); await p.keyboard.press('Enter')` (uzun metin için type DEĞİL insertText).
- Yeni proje: https://stitch.withgoogle.com/ ana sayfada kutuya ilk istemi yaz, "App" modu seçili olmalı (varsayılan), gönder; adres `/projects/<ID>` olur: ID'yi not et (sekme kuralındaki PROJE_KIMLIGI).
- Üretim ~4-8 dk. Bitti sayılır: sol paneldeki ajan günlüğünde dönen/'Thinking'/'Building' yazısı kalmaz, ekranlar net olur. Sonraki istemi bitmeden GÖNDERME.
- Tüm tuval: boş alana tıkla + Shift+1. Tek ekran incelemek için ekrana tıkla ve yakınlaştır (Ctrl+tekerlek) ya da sağ alttaki yakınlaştırma yüzdesini kullan; screenshot al ve OKU. "Üretildi" demeden özellik kontrol listesiyle tek tek karşılaştır.
- Düzeltme: ekrana tıkla (istem kutusunun üstünde ekran 'chip'i çıkar = istem o ekrana uygulanır), kısa İngilizce düzeltme istemi ("remove X, add Y, keep everything else"). Silme: ekranı seç + Delete (Stitch 'Undo' sunar). Hatalı/tekrar eden ekranları SİL. Dikkat: marquee (sürükle) seçiminde seçilen chip adlarını doğrula, silmeden önce.
- Aktarma: ekranları seç, Export -> `.zip` (HTML+görsel; tek seferde en çok 16 ekran). Zip'i `C:\bu_design\stitch\<NN>-<ad>\` altına çıkar (repo dışı, ASCII yol; indirme `.playwright-mcp` altında olabilir; taşımak/çıkarmak için Bash/PowerShell). Zip olmazsa her ekranın PNG'sini aynı klasöre kaydet. En az PNG olsun.

## İstem metni
ORTAK ÖNSÖZ (`docs/design/00-ortak-kurallar.md` içindeki önsöz bloğu) + boş satır + ilgili dosyanın `## Istem` kopyala-yapıştır bloğu. Metni run_code içine JSON.stringify edilmiş sabit string olarak yapıştır (ters eğik çizgi/backtick kaçışına dikkat). Her yeni projenin İLK isteminin başına şu cümleyi ekle: "Visual reference: the app is called BU Kampus, brand deep navy #171E33 and vivid red #F73A2E, white 20px rounded cards on #F6F7FA, Inter, floating pill bottom navigation; keep every screen in that single consistent style."

## Kontrol (her grup için)
00-ortak-kurallar.md yasakları ve "Stitch'in tipik hataları" tablosu: ödeme/bakiye/QR-ile-öde, hikâye, yorum, #etiket, @bahsetme, video gönderi, kaydet, boun.edu.tr (yalnız bingol.edu.tr), "Merkez/Güney Kampüs", eduroam, e-Devlet, hava durumu, "Bingöl Üniv." etiketi, "Resmî", v2.4.0 (doğrusu "Sürüm 2.0.3"), sahte durum çubuğu, bozuk Türkçe karakter. Başlık "BU Kampüs" + "Bağımsız öğrenci uygulaması"; yüzen pill 5 sekmeli alt gezinme (tam ekran/modal/giriş akışları hariç). Her istemin "Özellik kontrol listesi" maddeleri GÖRÜNÜR olmalı; eksikse düzeltme istemi (grup başına en çok 2 tur); hâlâ eksikse INDEX'e "eksik: ..." yaz.

## Kayıt (çakışmasız)
- Kendi rapor dosyan: `docs/design/RAPOR-<operatör>.md` (operatör adı: op1..op4). Grup başına 3-6 satır: üretilen, düzeltilen, Stitch'in tekrar eden halüsinasyonları, kalan eksikler, Stitch proje adresi, PNG/zip klasörü.
- `docs/design/INDEX.md` durum sütunu: yalnız KENDİ satırlarını `[x]` yap (küçük düzenleme; commit öncesi `git pull --rebase` değil, dosyayı yeniden oku ve yalnız kendi satırlarını değiştir; çakışma varsa yeniden dene).
- Commit: SADECE `scripts/agent-push.sh "DESIGN: Stitch <aralık> üretildi" docs/design/INDEX.md docs/design/RAPOR-<op>.md` (asla `git add .`; `mobile/` dosyalarına DOKUNMA: çalışma ağacında başkalarının commitlenmemiş dosyaları var).

## Sınırlar
Stitch kota/ekran sınırı hatası verirse DUR, durumu raporla. Sır/parola yazma. Bağlam dolmadan temiz bir noktada (bir istem grubu bittiğinde) dur ve nerede kaldığını raporla; sonraki operatör devam eder.

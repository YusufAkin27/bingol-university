# Risk / Etki Değerlendirmesi (Kısa DPIA) (İç Belge)

Konu: (1) mesaj içeriklerine yönetici erişimi, (2) cihaz/IP kayıtları ve erişim engelleri, (3) akademisyen alanı: öğrenci rehberi ve ders yoklaması. KVKK'da zorunlu "DPIA" kavramı yoktur; bu değerlendirme meşru menfaat dengesi ve m.12 tedbirleri için iyi uygulamadır.

## 1. Mesaj içeriklerine yönetici erişimi

| | |
|---|---|
| Amaç | Şikâyet/rapor incelemesi, güvenlik, yasal talepler |
| Gereklilik | Çevrimiçi taciz, tehdit, çocuk güvenliği ve dolandırıcılık raporlarında içerik görülmeden karar verilemez; "gölge engel" ve silinen mesajlar nedeniyle yalnızca kullanıcı görünümü yetersiz kalır |
| Orantılılık | Yalnızca yönetici rolü; ihtiyaç ilkesi; her sayfa erişimi ön-kayıtlı; silinmiş mesajlar da görülebildiği için kapsam geniştir (üyelik penceresi sınırı yok) |
| Etkilenenler | Tüm kullanıcılar (özel yazışma); özellikle hassas bilgi paylaşabilecek kişiler |
| Veri | Mesaj metni, medya, düzenleme geçmişi, silinmiş mesajlar, tek gönderimlik görsel (365 gün) |

| Risk | Olasılık | Etki | Mevcut önlem | Kalan risk / ek önlem |
|---|---|---|---|---|
| Yetkisiz/merak amaçlı görüntüleme | Orta | Yüksek | Rol, kayıt, yalnızca-ekleme denetim, kullanıcıya şeffaf bilgilendirme | Aylık denetim gözden geçirmesi, gerekçe defteri (04), taahhütname (07) |
| Yönetici hesabı ele geçirilmesi | Düşük-orta | Çok yüksek | Kısa ömürlü JWT, rate limit, `rolechg` | 2. faktör, güçlü parola, yönetici sayısını asgari tutma |
| Ana anahtar sızıntısı | Düşük | Çok yüksek | Anahtar ortamda, DB'de değil; rotasyon aracı | Anahtar yedeği ayrı; erişim kısıtı |
| Denetim kaydının silinmesi | Düşük | Yüksek | DB tetikleyicisi | DB kullanıcısından DDL yetkisi alma, dış arşiv |
| Gerekçe serbest metni kodda yok | Kesin | Orta | Sabit sistem gerekçesi | Panel dışı erişim defteri (04); ileride gerekçe alanı eklenmesi önerisi |
| Süresiz saklanan silinmiş mesajlar | Kesin (varsayılan) | Orta | Şifreli | Saklama süresi kararı (`app.chat.deleted-retention-days`) |
| Kullanıcının beklentisi (E2EE sanması) | Orta | Orta | Metinlerde açık "uçtan uca değil" ifadesi | Mağaza ve arayüz metinlerinde "uçtan uca" denmemesi |

**Sonuç:** Önlemler (rol, ön-kayıtlı değiştirilemez denetim, şeffaf bilgilendirme) koşuluyla meşru menfaat dengelenebilir. Kalan riskler için 04 numaralı politika ve LEGAL_CHECKLIST kararları gereklidir.

## 2. Cihaz / IP kayıtları ve erişim engeli

| | |
|---|---|
| Amaç | Yasaklı kullanıcının yeniden kayıt/oturumla engeli dolanmasını önleme, kötüye kullanım tespiti |
| Veri | Cihaz tanımlayıcı HMAC özeti (ham değer saklanmaz), IP, platform, sürüm, zaman; engellenen deneme günlüğü |
| Süre | 90 gün (5651 kararı bekliyor) |
| Etkilenenler | Tüm kullanıcılar (IP/cihaz kaydı); ban sistemi nedeniyle ortak IP (yurt/kampüs NAT, CGNAT) kullanan masumlar |

| Risk | Olasılık | Etki | Önlem | Kalan risk |
|---|---|---|---|---|
| Yanlış pozitif: ortak IP/CIDR engeli masumları kapatır | Orta | Orta | Engellerin süreli olabilmesi, `hit_count` izleme, itiraz yolu | Kampüs IP aralıklarını engelleme listesine almama (beyaz liste) |
| Cihaz özeti ile kullanıcı izleme | Düşük | Orta | HMAC, ham ID saklanmaz, 90 gün | Anahtar (`DEVICE_HMAC_KEY`) ayrı yönetimi |
| Hukuki saklama yükümlülüğü ile süre uyuşmazlığı | Orta | Orta | Ayarlanabilir süre | **Karar gerekir** (LEGAL_CHECKLIST) |
| Anonimleştirici (VPN/Tor) engelinin meşru kullanıcıyı etkilemesi | Orta | Düşük-orta | İtiraz/Destek yolu | Bildirim metni |

**Sonuç:** Güvenlik amaçlı ve sınırlı süreli kayıt orantılıdır; ortak IP engellerinde dikkat ve itiraz mekanizması şarttır.

## 3. Akademisyen alanı: öğrenci rehberi ve ders yoklaması (V1910, TASLAK)

| | |
|---|---|
| Amaç | Akademisyenin kendi dersine öğrenci eklemesi, QR/elle yoklama, devamsızlık takibi, ders duyurusu |
| Veri | Öğrenci rehberi: görünen ad, öğrenci numarası (e-posta yerel kısmından türetilir), fakülte, bölüm, sınıf; ders kaydı; yoklama satırı (durum, yöntem, zaman, işleyen); bekleyen okutma isteği; devamsızlık uyarı durumu; duyuru ve ekleri. Konum ve cihaz kimliği YOK |
| Gereklilik | Hocanın öğrenciyi tek tek aratıp ekleyebilmesi için ad/numara/bölüm gerekir; ancak **tüm onaylı akademisyenlerin tüm öğrenci listesini görmesi** ders ekleme ihtiyacının ötesine geçer (alternatif: yalnız kendi bölümü, ya da öğrenci kendini koda okutarak eklenir) |
| Orantılılık | E-posta, fotoğraf, biyografi gösterilmez; rehber hız sınırlı ve günlük kotalı; akademisyen onay kapısından geçer; ancak profil gizlilik ayarı rehberde işlemez ve öğrencinin rehberden çıkma ayarı yoktur |
| Etkilenenler | Tüm kayıtlı ve profili tamam öğrenciler (rehber); derse eklenen öğrenciler (yoklama) |

| Risk | Olasılık | Etki | Mevcut önlem | Kalan risk / ek önlem |
|---|---|---|---|---|
| Sahte/yetkisiz akademisyenin tüm öğrenci listesine erişmesi | Orta | Yüksek | Yönetici onayı veya otomatik onay (e-posta örüntüsü: kodla doğrulanmış bingol.edu.tr, harfli yerel kısım, sınıf bilgisi yok); iptal edilen akademisyen 403 | Otomatik onay personel doğrulaması DEĞİLDİR; ek: yalnız yönetici onayı (`app.academician.auto-approve=NEVER`), rehberi bölümle sınırlama, rehber erişim kaydı |
| Rehberin toplu kopyalanması | Orta | Orta | 60/dk hız sınırı + günlük kota, imeç sayfalama | Tam liste yine sayfalanarak çekilebilir; kullanım koşullarında yasak (4.11) |
| Öğrencinin rehberden çıkamaması / ders kaydını kendisinin silememesi | Kesin | Orta | Destek yolu, metinde açık ifade | Kendi çıkış/itiraz ayarı (ürün kararı) |
| Süresiz saklama (ders ve yoklama) | Kesin | Orta | Ders/hesap silinince silinir | Dönem sonu otomatik silme veya arşivleme süresi (karar gerekir) |
| CSV dışa aktarımın akademisyenin cihazında kontrolsüz kalması | Orta | Orta | Metinde bildirim, kullanım koşulu | Ek teknik önlem yok |
| Yoklama verisinin "resmî" sayılması ve yanlış kaydın öğrenciye zararı | Orta | Orta | Hocanın son sözü (elle düzeltme), öğrenci kendi kaydını görür | Üniversitenin resmî kaydı yerine geçmediği ifadesi (Koşullar 15.3) hukuk onayına bağlı |

**Sonuç:** Rehber görünürlüğü orantılılık sınırındadır; hukuki dayanak (m.5/2-f) ve ek önlemler hukuk danışmanı kararına bağlıdır (`academician-revision-notes.md`).

## 4. Gözden geçirme

Yılda bir ve önemli özellik değişikliğinde (ör. konumun sunucuda işlenmesi, mesaj önizlemeli push, E2EE geçişi) yeniden yapılır.

# 08 - Verilerim (KVKK) ve hesabı silme

## Kapsam
- Envanter 98 `MyDataPage`, 99 `DeleteAccountPage`, alt sayfa A58 (şifre isteyen silme onayı)

## Istem
```text
Design 4 separate mobile screens (no bottom nav, header with back arrow).

1) "Verilerim" page. Intro: "KVKK kapsamında uygulamada sakladığımız kişisel verilerinin bir kopyasını indirebilirsin." File card with document icon: "JSON dosyası olarak hazırlanır". Section "Dosyada neler var" with 5 check rows: "Profil bilgilerin", "Gizlilik ve bildirim tercihlerin", "Kulüp ve etkinlik kayıtların", "Kayıtlı haberler ve bildirimlerin", "Destek ve geri bildirim kayıtların". Note: "Günde en fazla 3 kez indirebilirsin. Dosyayı güvenli sakla, içinde kişisel bilgiler var." Primary button "Verilerimi indir". Section "Diğer": row "KVKK aydınlatma metni" with chevron, row "Hesabımı sil" in danger color.

2) "Verilerim" with feedback states. Same page; top success toast "Verileriniz panoya kopyalandı" and an error card below the button: "Günde en fazla 3 kez veri indirebilirsiniz." (limit reached, button disabled).

3) Delete account page. Red-tinted warning card: bold "Bu işlem geri alınamaz." + "Hesabın anonimleştirilir ve bir daha giriş yapamazsın." Section "Neler olur" with 6 bullet rows: "Adın, e-postan, fotoğrafın ve profil bilgilerin silinir. Hesap Silinmiş kullanıcı olarak kalır." ; "Bildirimlerin, kayıtlı haberlerin, cihaz kayıtların ve tercihlerin silinir." ; "Kulüp üyeliklerin ve etkinlik katılımların kaldırılır." ; "Sahibi olduğun kulüpler yönetici üyeye devredilir; aday yoksa kulüp kapatılır." ; "Cihaz, IP ve kullanım (analitik) kayıtların anında silinir." ; "Tüm cihazlardaki oturumların kapanır." Hint: "Dilersen silmeden önce verilerini indirebilirsin." Checkbox "Hesabımın kalıcı olarak silineceğini ve geri alınamayacağını anladım." Danger button "Devam et" (disabled until checked), text button "Vazgeç".

4) Password confirmation bottom sheet over dimmed screen 3, lifted by the keyboard. Title "Silmeyi onayla", body "Devam etmek için şifreni gir. Hesabın hemen anonimleştirilir ve tüm cihazlardan çıkış yapılır." Password field "Şifre" with eye icon, error "Şifre hatalı.", danger button "Hesabımı sil", text button "Vazgeç". Show the on-screen keyboard.
```

## Özellik kontrol listesi
- [ ] Verilerim: giriş metni, JSON dosya kartı, içerik listesi (5 madde), günlük 3 sınır notu, Verilerimi indir
- [ ] KVKK aydınlatma metni satırı, Hesabımı sil satırı
- [ ] Başarı bildirimi ve sınır aşıldı hata kartı
- [ ] Silme: uyarı kartı, "Neler olur" (6 madde), yedek ipucu, onay kutusu, pasif/aktif tehlike düğmesi
- [ ] Şifre onay sheet: şifre alanı, hata, Hesabımı sil, Vazgeç, klavye

## Dikkat
- Silme, "askıya alma/geçici devre dışı bırakma" değildir; geri dönüş yolu gösterilmesin.
- Kullanıcı verisi PDF/CSV indirme seçeneği yok; tek biçim JSON.

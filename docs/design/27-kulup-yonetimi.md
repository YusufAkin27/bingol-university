# 27 - Kulüp yönetimi: üyeler, başvurular, kulüp kur/düzenle

## Kapsam
- Envanter 59 `ClubMembersPage`, 60 `ClubRequestsPage`, 62 `ClubFormPage` (oluştur/düzenle); kapak 16:9 ve logo 1:1 kırpma akışı için `09-fotograf-kirpma.md`

## Istem
```text
Design 6 separate mobile screens (no bottom nav, header with back arrow).

1) Club members (I am the club owner). Header "Üyeler", subtitle "Robotik Kulübü · 86 üye". Search field "Üye ara". Rows: avatar, name, role tag ("Yönetici" in red tint, "Moderatör" in blue tint, no tag for plain members), trailing "⋯" button ("Üye işlemleri").

2) Member action bottom sheet over the list for "Zeynep Arslan". Rows: "Moderatör yap" (or "Üye yap" if moderator), "Kulüpten çıkar", "Yasakla" (red). Below it two confirmation texts shown as a dialog: title "Kulüpten çıkar", body "Zeynep Arslan kulüpten çıkarılsın mı? Kulüp sohbetinden de düşer.", buttons "Vazgeç" / "Çıkar". (Ban variant body: "Zeynep Arslan kulüpten çıkarılsın ve bir daha katılamasın mı?")

3) Join requests. Header "Başvurular", sub "3 bekliyor". Cards: avatar, name, department, and the applicant's answers as question/answer pairs ("Neden katılmak istiyorsun?" -> "Robotik ile ilgileniyorum."). Buttons "Reddet" (outline) and "Onayla" (primary); one card in loading state with "Onaylanıyor...". Bottom button "Daha fazla başvuru".

4) Empty states. Requests empty: illustration and "Bekleyen başvuru yok." Members search empty: "Üye bulunamadı." Plus a load error row "Yüklenemedi, tekrar dene".

5) Create club form. Header "Kulüp kur". Cover upload area "Kapak ekle (isteğe bağlı)" 16:9 and a round logo upload "Logo ekle" 1:1. Fields: "Kulüp adı" (hint "Örn. Robotik Kulübü"), "Kısa açıklama" ("Kulüp ne yapıyor?"), "Kategori" ("Listeden seç ya da yaz (isteğe bağlı)"). Segmented "Görünürlük": "Herkese açık" / "Gizli" with hints "Kulüp Keşfet listesinde görünür." / "Kulüp içeriğini yalnızca üyeler görür; katılım onayla olur." Segmented "Katılım": "Serbest" / "Onaylı" with hint "Katılmak isteyenler başvuru gönderir, sen onaylarsın." Section "Katılım soruları (en çok 3)" with text fields "Soru 1", remove icon, "Soru ekle". Primary button "Kulübü oluştur".

6) Edit club form. Header "Kulübü düzenle", prefilled values, cover with "Kapağı değiştir". Errors under fields: "Kulüp adı en az 3 karakter olmalı.", "Seçilen kategori geçerli değil. Listeden başka bir kategori seç." Warning banner "Kulüp kaydedildi ancak kapak ya da katılım soruları kaydedilemedi." Button "Kaydet".
```

## Özellik kontrol listesi
- [ ] Üyeler: arama, rol etiketleri (Yönetici, Moderatör), Üye işlemleri
- [ ] Üye işlemleri: Moderatör yap / Üye yap, Kulüpten çıkar, Yasakla + onay metinleri
- [ ] Başvurular: sayaç, cevaplar, Reddet / Onayla, onaylanıyor durumu, daha fazla
- [ ] Boş / hata durumları
- [ ] Kulüp kur: kapak, logo, ad, açıklama, kategori, görünürlük, katılım türü, katılım soruları (ekle/kaldır), Kulübü oluştur
- [ ] Düzenle: dolu alanlar, doğrulama hataları, kısmi kaydetme uyarısı, Kaydet

## Dikkat
- Üyelik ücreti, aidat, ödeme alanı yok.
- Roller yalnız Yönetici (sahip), Moderatör, Üye; "Başkan yardımcısı" gibi roller uydurmasın.
- Katılım soruları metin cevaplıdır; çoktan seçmeli yok.

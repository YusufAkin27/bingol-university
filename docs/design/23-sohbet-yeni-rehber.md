# 23 - Yeni sohbet, grup oluşturma ve rehberden kişi bulma

## Kapsam
- Envanter 45 `NewChatPage`, 46 `ContactsMatchPage` (izin gerek, yükleniyor, hazır, eşleşme yok, hata)

## Istem
```text
Design 6 separate mobile screens (no bottom nav, header with back arrow).

1) New chat start. Header "Yeni sohbet". Search field "Ad veya e-posta ile ara". Two action cards: "Yeni grup" (people icon, subtitle "En fazla 50 kişi") and "Rehberden kişi bul" (contacts icon, subtitle "Bingöl Üniversitesi kişileri"). Hint text below: "Kişi aramak için en az 2 karakter yazın."

2) Search results. Query "mehmet". Section label "KİŞİLER". Rows: avatar, "Mehmet Kaya", "Makine Mühendisliği · 3. sınıf"; tapping starts a direct chat ("Sohbet başlat" as small text on the right of the first row). Empty variant line below: "Eşleşen kişi bulunamadı."

3) Group creation. Header "Yeni grup". Selected people shown as removable avatar chips with count "2 kişi seçildi". Field "Grup adı" with helper "en çok 50". Validation lines: "Grup için en az 2 kişi seçin." and "Grup adı girin." Selectable people list with circular checkboxes. Bottom primary button "Grubu oluştur".

4) Contacts match - permission needed. Header "Rehberden kişi bul". Illustration, title "Rehber izni gerekli", text "Rehberinizdeki kampüs kişilerini bulabilmemiz için rehbere erişim izni vermeniz gerekir.", privacy line "Rehberiniz sunucuya gönderilmez.", button "İzin ver", secondary "Ayarlardan aç".

5) Contacts match - ready. Subtitle "Bingöl Üniversitesi kişileri". Search "Kişilerde ara". Label "5 KİŞİ". Rows: avatar, name, department, outlined small button "Mesaj". Footer privacy note: "Rehberin sunucuya gönderilmez; yalnızca e-posta özetleri eşleştirilir." Amber note: "Saatlik istek sınırına ulaşıldı; kalan kişiler daha sonra eşleştirilecek."

6) Contacts match - loading and empty. Top: skeleton rows. Below: empty card "Eşleşen kişi yok" with text "Rehberindeki kişilerden Bingöl Üniversitesi e-postasıyla uygulamayı kullanan kimse bulunamadı." and a separate line "Aramanla eşleşen kişi yok." plus error row with "Yeniden dene".
```

## Özellik kontrol listesi
- [ ] Yeni sohbet: arama, "Yeni grup" kartı, "Rehberden kişi bul" kartı, 2 karakter ipucu
- [ ] Sonuç satırları (bölüm/sınıf), sonuç yok
- [ ] Çoklu seçim = grup: seçili çipler, sayaç, grup adı (en çok 50), doğrulama hataları, Grubu oluştur
- [ ] Rehber: izin gerekli / hazır / yükleniyor / eşleşme yok / arama eşleşmedi / hata
- [ ] Gizlilik notu (rehber sunucuya gönderilmez)
- [ ] Saatlik sınır uyarısı

## Dikkat
- Telefon numarası göstermesin; eşleşme e-posta özetiyle yapılır, satırlarda telefon yok.
- "Davet et / SMS gönder" düğmesi yok.

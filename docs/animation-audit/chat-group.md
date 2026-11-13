# Animasyon denetimi: chat-group (chat, share, media_crop, shell, system)

Genel bulgu: kapsam zaten olgun. Tum sureler BuMotion.of/reduced ile saygili; balon girisi (`chat/bubble_entry.dart`),
tepki pop'u (`message_bubble.dart:802`), AnimatedSwitcher durum ikonlari (`message_status_icon.dart:72`), medya
goruntuleyici gecisleri (`chat_media_parts.dart`), secim daireleri/AnimatedContainer (`chat_sheet_parts.dart`,
`sohbety_widgets.dart`), alt sayfa boyut gecisleri (`share_sheet.dart:291`), kapi ekranlari BuStaggerItem
(`system/gate_views.dart`) ve acilis ilerlemesi (`splash_screen.dart:37`) mevcut ve ucuz (opacity/transform).

| Sayfa | Dosya:satir | Mevcut | Eksik/zayif | Yapilan |
|---|---|---|---|---|
| Ilet sheet listesi | chat/forward_sheet.dart:181 | yok (satirlar aniden) | liste girisi | BuStaggerItem (ilk 8) |
| Uye ekle | chat/sohbety_add_members.dart:166 | yok | liste girisi | BuStaggerItem |
| Paylasim alici listesi | share/share_sheet.dart:446 | yok | liste girisi | BuStaggerItem |
| Bolum sohbetleri | chat/department_chats_page.dart:157 | yok | liste girisi | BuStaggerItem |
| Hata gorunumu Tekrar dene | system/error_views.dart:82 | yalniz InkWell | basma olcegi | BuPressable (olcek) |

Oneri (yapilmadi): chat_tab.dart (baska ajan/sabit baslik), chat_detail_page.dart 4000+ satir (riskli, zaten
AnimatedSwitcher/Rotation var), media_crop (surukleme odakli, animasyon gereksiz), shell (alt gezinme ayri ajanda).
new_chat_page.dart:310 secili kisi cipi InkWell: BuPressable ile sarilabilir; message_requests_page InkWell satirlari
ortak BuPressable'a gecebilir (baska ajanin dosyasi, dokunulmadi).

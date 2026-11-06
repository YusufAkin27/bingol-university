# Android ana ekran widget'lari (RemoteViews)

Sözleşme: `design/widget-previews/DATA_CONTRACT.md`, tasarım: `design/widget-previews/DESIGN_SYSTEM.md`. Bu belge yalnız Android uygulamasının kararlarını ve çalışma biçimini anlatır.

## Karar: Glance değil RemoteViews

Jetpack Glance denendi/değerlendirildi ve **bırakıldı**. Gerekçe:

- Tasarım `letter-spacing` (caption +0.08em, display -0.02em) ve satır yüksekliği (13/18, 22/26...) ister; Glance `TextStyle` ikisini de desteklemez. RemoteViews'ta `android:letterSpacing` + `android:lineHeight` XML'de verilir.
- Glance `cornerRadius` yalnız API 31+; uygulamanın minSdk'sı 24. Şekil drawable'ları (köşe 28/14/12/8 + 1 dp kenarlık) her sürümde çalışır.
- Glance Compose derleyici eklentisi ister (AGP 9 + Kotlin 2.4 uyumu riski; `home_widget` Glance kütüphanesini zaten getirir ama biz yalnız RemoteViews kullanırız). RemoteViews ek derleme eklentisi gerektirmez.
- Renkler XML'de `@color/bu_widget_*` (values / values-night): sistem teması değişince launcher yeniden çizer, kodla renk vermek bayat kalırdı.

## Yapı

- `res/layout/bw_<slug>_{small,medium,large}.xml`, `bw_empty_*`, `bw_signedout.xml`, `res/drawable/ic_w_*` (Lucide vector), `bw_*` şekiller: **üretilmiştir**, elle düzenlemeyin. Üreticiler: `mobile/tool/gen_android_widgets_{icons,layouts,meta}.py` (`python -I -X utf8 ...`).
- `kotlin/.../widgets/`: `WidgetCore.kt` (kapı: oturumsuz/boş/ok, saat, JSON yardımcıları), `WidgetModels.kt` (slug modelleri, seçim mantığı), `WidgetRenderer.kt` (RemoteViews bağlama), `BuWidgetReceiver.kt` (sağlayıcı tabanı, güncelleyici, alarm), `WidgetReceivers.kt` (üretilmiş: 7 slug x 3 sağlayıcı).
- Her slug için 3 sağlayıcı: sözleşme adı `<Slug>WidgetReceiver` = 2x2, `<Slug>Widget4x2Receiver`, `<Slug>Widget4x4Receiver`. Hepsi aynı çizimi yapar; yerleşim sınıfı gerçek widget boyutundan seçilir (genişlik < 250 dp = 2x2, yükseklik < 250 dp = 4x2, diğeri 4x4) ve yeniden boyutlandırınca değişir.
- Uygulama `HomeWidget.updateWidget` ile adı geçen sağlayıcıya yayın gönderince slug'ın **tüm** sağlayıcıları yenilenir (yalnız 4x4 eklenmiş olsa da).
- Veri: `SharedPreferences("HomeWidgetPreferences")` `bu_widget_<slug>`; bozuk/eksik/`schema > 1` → oturumsuz düzen, çökme yok.

## Yenileme

`updatePeriodMillis` 30 dk + uygulamanın snapshot yazımı sonrası `updateWidget` + tek esnek alarm (`setAndAllowWhileIdle`, kesin alarm izni YOK): gece 00:05, menü için 12:00/18:00, bugünkü ders başlangıç/bitişleri. Açılış/paket güncelleme/saat değişimi: `WidgetRefreshReceiver`. `HomeWidgetScheduledUpdateReceiver` manifest'te (uygulamanın gece yarısı alarmı için).

## Debug doğrulama

`src/debug` altındaki `WidgetHostActivity` (yalnız debug) gerçek `AppWidgetHostView` ile 2x2/4x2/4x4 boyutlarını çizer:

```
adb shell cmd appwidget grantbind --package tr.com.bukampus.app
# fixture: <externalFilesDir>/widgets_fixture.json  {"bu_widget_meta":{...},"bu_widget_menu":{...},"debug_now":"2026-11-06T10:00:00+03:00"}
adb shell am start -n tr.com.bukampus.app/edu.bingol.bu_kampus.widgets.WidgetHostActivity --es slug menu
adb shell cmd uimode night yes   # koyu tema
```

`debug_now` saat geçersiz kılma yalnız `FLAG_DEBUGGABLE` derlemede etkindir.

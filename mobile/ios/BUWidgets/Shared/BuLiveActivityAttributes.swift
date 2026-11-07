// BuLiveActivityAttributes.swift
// Canli Etkinlik (ActivityKit) veri modeli. Runner (baslatma/bitirme) ve BUWidgets (cizim) hedeflerinin IKISINE de eklenir.
//
// KAPSAM (kesin): yalniz kullanicinin kendi baslattigi gercek surecler:
//   EVENT = katildigi etkinligin baslangic/bitis geri sayimi, EXAM = kendi girdigi sinavin geri sayimi.
// Sohbet, arkadaslik, duyuru ve benzeri bildirimler ASLA Canli Etkinlik olmaz.
// Gizlilik: yalnizca kullanicinin kendi sectigi baslik/yer girilir; baska kullanicinin verisi yoktur.
// UYARI: Windows'ta derlenemedi; ilk macOS/Codemagic derlemesinde dogrulayin (docs/IOS_RELEASE.md).

import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct BuLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// "upcoming" (baslamasina geri sayim), "live" (surerken, bitisine geri sayim), "ended".
        var phase: String
        /// Geri sayimin hedef ani (upcoming: baslangic, live: bitis).
        var target: Date
        /// Cihaz dilinde kisa durum etiketi (uygulama uretir).
        var label: String
        /// Kisa ikinci satir (yer vb.); bos olabilir.
        var detail: String
    }

    /// "EVENT" | "EXAM"
    var kind: String
    var refId: Int64
    var title: String
}

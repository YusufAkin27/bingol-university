// BuWidgetTokens.swift
// Ana ekran widget'lari (WidgetKit) merkezi tasarim belirtecleri.
//
// KAYNAK: design/widget-previews/DESIGN_SYSTEM.md tablolari. Ayni degerler Dart'ta
// mobile/lib/features/widgets/widget_tokens.dart ve Android'de widgets/WidgetTokens.kt icindedir;
// mobile/test/widgets/widget_tokens_test.dart uc dosyayi ve tabloyu karsilastirir. Degeri YALNIZ tablo + Dart ile
// birlikte degistirin. Renkler BuTokens'tan (mobile/lib/core/theme.dart) turetilmistir.
//
// Birim: pt. Yazi tipi sistem fontudur (SF; Arapcada sistem yedegi), AGIRLIK HER YERDE .regular (400): kalin yazi yok.
// Bu dosya Widget Extension hedefine (BUWidgets) eklenecek; Runner hedefine eklenmez.

import SwiftUI

enum BuWidgetTokens {

    // MARK: Kabuk
    static let paddingDefault: CGFloat = 16
    static let paddingQuickSmall: CGFloat = 12   // yalniz Hizli Erisim small
    static let borderWidth: CGFloat = 1
    static let cornerRadius: CGFloat = 22        // iOS konteyner koseleri

    /// Referans olculer (tasarim PNG'leri bu olcude). Gercek cihazda genislik/yukseklik degisir; duzen esnek.
    static let sizeSmall = CGSize(width: 158, height: 158)
    static let sizeMedium = CGSize(width: 338, height: 158)
    static let sizeLarge = CGSize(width: 338, height: 354)

    // MARK: Yazi (boyut / satir yuksekligi / harf araligi em / BUYUK)
    struct TextRole {
        let size: CGFloat
        let line: CGFloat
        let tracking: CGFloat   // em
        let caps: Bool
        init(_ size: CGFloat, _ line: CGFloat, tracking: CGFloat = 0, caps: Bool = false) {
            self.size = size; self.line = line; self.tracking = tracking; self.caps = caps
        }
        /// SwiftUI: .font(.system(size: size, weight: .regular)).tracking(trackingPoints).lineSpacing(lineSpacing)
        var trackingPoints: CGFloat { tracking * size }
        var lineSpacing: CGFloat { max(0, line - size * 1.2) }
    }

    static let fontWeight: Font.Weight = .regular

    static let caption = TextRole(10, 12, tracking: 0.08, caps: true)
    static let micro = TextRole(11, 14)
    static let small = TextRole(12, 16)
    static let body = TextRole(13, 18)
    static let bodyL = TextRole(14, 18)
    static let question = TextRole(15, 20, tracking: -0.01)
    static let title = TextRole(17, 22, tracking: -0.01)
    static let display = TextRole(22, 26, tracking: -0.02)
    static let number = TextRole(34, 38, tracking: -0.03)
    static let numberRow = TextRole(28, 32, tracking: -0.03)
    static let badgeDaySmall = TextRole(13, 13)
    static let badgeMonthSmall = TextRole(9, 10, tracking: 0.08, caps: true)
    static let badgeDayLarge = TextRole(18, 20)
    static let badgeMonthLarge = TextRole(10, 12, tracking: 0.08, caps: true)
    static let eventDayHero = TextRole(34, 36, tracking: -0.03)

    // MARK: Bosluk olcegi
    static let s2: CGFloat = 2
    static let s4: CGFloat = 4
    static let s6: CGFloat = 6
    static let s8: CGFloat = 8
    static let s10: CGFloat = 10
    static let s12: CGFloat = 12
    static let s14: CGFloat = 14
    static let s16: CGFloat = 16

    // MARK: Kose yaricaplari
    static let radiusRow: CGFloat = 12
    static let radiusTile: CGFloat = 14
    static let radiusChip: CGFloat = 12
    static let radiusBadgeSmall: CGFloat = 8
    static let radiusBadgeLarge: CGFloat = 10
    static let radiusBar: CGFloat = 2
    // "Oy ver" hapi: Capsule() kullanin (tam yuvarlak).

    // MARK: Ikon (Lucide cizgi, vurus 1.5, round). Ikonlar SF Symbols DEGIL: ozel SVG/PDF varliklari (Lucide adlariyla).
    static let iconStroke: CGFloat = 1.5
    static let iconHeader: CGFloat = 12
    static let iconHeaderEvents: CGFloat = 14
    static let iconMeta: CGFloat = 12
    static let iconMetaLarge: CGFloat = 14
    static let iconRowLarge: CGFloat = 22
    static let iconTileMedium: CGFloat = 18
    static let iconTileLarge: CGFloat = 24
    static let iconEmptySmall: CGFloat = 20
    static let iconEmptyMedium: CGFloat = 22
    static let iconEmptyLarge: CGFloat = 28
    static let iconSocialMedium: CGFloat = 18

    // MARK: Baslik satiri / logo
    static let headerHeight: CGFloat = 16
    static let headerGap: CGFloat = 12
    static let logoHeight: CGFloat = 12
    static let logoHeightEvents: CGFloat = 14
    static let logoOpacity: Double = 0.9

    // MARK: Satir / karo olculeri
    static let rowTimetableMedium: CGFloat = 36
    static let rowTimetableLarge: CGFloat = 40
    static let rowEvents: CGFloat = 30
    static let rowSocialLarge: CGFloat = 64
    static let badgeEventLargeWidth: CGFloat = 44
    static let badgeEventLargeHeight: CGFloat = 48
    static let badgeTimetableWidth: CGFloat = 52
    static let pillHeight: CGFloat = 28
    static let pillPaddingX: CGFloat = 14
    static let kcalChipHeight: CGFloat = 36
    static let barHeight: CGFloat = 4
    static let tileGap: CGFloat = 8
    static let opacityPastLesson: Double = 0.5
    static let opacityNonLeaderBar: Double = 0.45

    // MARK: Boyuta gore icerik sayilari
    static let menuSmallMainLines = 2
    static let menuMediumDishes = 3
    static let menuLargeDishes = 4
    static let menuLargeDishesSingleMeal = 8
    static let timetableSmallTitleLines = 2
    static let timetableMediumRows = 2
    static let timetableLargeRows = 4
    static let eventsSmall = 1
    static let eventsMedium = 3
    static let eventsLarge = 3
    static let announcementsSmall = 1
    static let announcementsMedium = 3
    static let announcementsLarge = 4
    static let announcementsSmallTitleLines = 4
    static let announcementsLargeTitleLines = 2
    static let pollSmallQuestionLines = 3
    static let pollMediumQuestionLines = 3
    static let pollMediumOptions = 3
    static let pollLargeQuestionLines = 2
    static let pollLargeOptionsMax = 4
    static let quickSmallTiles = 4
    static let quickMediumTiles = 8
    static let quickLargeTiles = 8
    static let socialMediumColumns = 3
    static let socialLargeRows = 3

    // MARK: Veri sozlesmesi (design/widget-previews/DATA_CONTRACT.md)
    static let appGroup = "group.tr.com.bukampus.app"
    static let keyMeta = "bu_widget_meta"
    static let keyMenu = "bu_widget_menu"
    static let keyTimetable = "bu_widget_timetable"
    static let keyEvents = "bu_widget_events"
    static let keyAnnouncements = "bu_widget_announcements"
    static let keyPoll = "bu_widget_poll"
    static let keyQuickAccess = "bu_widget_quickaccess"
    static let keySocial = "bu_widget_social"
    static let urlScheme = "bukampus"
}

/// Renk paleti. Degerler 0xRRGGBB (BuTokens karsiliklari DESIGN_SYSTEM.md'de).
struct BuWidgetPalette {
    let bg: UInt32
    let chip: UInt32
    let border: UInt32
    let text1: UInt32
    let text2: UInt32
    let text3: UInt32
    let inverseBg: UInt32
    let inverseFg: UInt32
    let barFill: UInt32
    let barTrack: UInt32
    let badgeFill: UInt32
    let badgeBorder: UInt32
    let dotPassive: UInt32
    let heart: UInt32      // YALNIZ begeni kalbi
    let danger: UInt32     // YALNIZ acil duyuru

    static let light = BuWidgetPalette(
        bg: 0xFFFFFF, chip: 0xF4F4F5, border: 0xE4E4E7,
        text1: 0x09090B, text2: 0x52525B, text3: 0x71717A,
        inverseBg: 0x09090B, inverseFg: 0xFFFFFF,
        barFill: 0x09090B, barTrack: 0xE4E4E7,
        badgeFill: 0xF4F4F5, badgeBorder: 0xE4E4E7, dotPassive: 0x8A8A93,
        heart: 0xDC2626, danger: 0xC81E1E)

    static let dark = BuWidgetPalette(
        bg: 0x09090B, chip: 0x1C1C1F, border: 0x303034,
        text1: 0xFAFAFA, text2: 0xA1A1AA, text3: 0x71717A,
        inverseBg: 0xFAFAFA, inverseFg: 0x09090B,
        barFill: 0xFAFAFA, barTrack: 0x303034,
        badgeFill: 0x1C1C1F, badgeBorder: 0x303034, dotPassive: 0x71717A,
        heart: 0xEF4444, danger: 0xF87171)

    /// Widget'ta: @Environment(\.colorScheme) ile cagirin. Tema = sistem (uygulama temasi widget'a yansimaz).
    static func palette(for scheme: ColorScheme) -> BuWidgetPalette {
        scheme == .dark ? .dark : .light
    }

    static func color(_ rgb: UInt32) -> Color {
        Color(.sRGB,
              red: Double((rgb >> 16) & 0xFF) / 255,
              green: Double((rgb >> 8) & 0xFF) / 255,
              blue: Double(rgb & 0xFF) / 255,
              opacity: 1)
    }
}

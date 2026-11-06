// BuWidgetModels.swift
// Veri sozlesmesi (design/widget-previews/DATA_CONTRACT.md, schema 1) modelleri + yukleme + zaman yardimcilari.
// KURAL: Widget AG ISTEGI ATMAZ; yalniz App Group UserDefaults'tan JSON okur. Bozuk/eksik/surum uyusmayan
// veri ASLA cokmeye yol acmaz (try? + opsiyoneller) ve oturumsuz duzene doner; ornek veri UYDURULMAZ.
// Bilinmeyen alanlar yok sayilir (Decodable); alan eklemek geriye uyumludur.

import Foundation
import WidgetKit

// MARK: - Zaman (Europe/Istanbul = sabit UTC+3, yaz saati yok)

enum BuTime {
    static let tz: TimeZone = TimeZone(secondsFromGMT: 3 * 3600) ?? TimeZone.current

    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// "2026-11-06T10:00:00+03:00" -> Date (bozuksa nil).
    static func parseISO(_ s: String?) -> Date? {
        guard let s = s, !s.isEmpty else { return nil }
        return isoFormatter.date(from: s)
    }

    /// Istanbul takvim gunu "yyyy-MM-dd".
    static func dayString(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Gece yarisindan beri gecen dakika (Istanbul).
    static func minutes(_ d: Date) -> Int {
        let c = cal.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func startOfDay(_ d: Date) -> Date {
        return cal.startOfDay(for: d)
    }

    /// Bir gunun (Istanbul) gece yarisina `minutes` dakika eklenmis hali.
    static func date(onDayOf d: Date, minutes: Int) -> Date {
        return startOfDay(d).addingTimeInterval(TimeInterval(minutes * 60))
    }

    /// Bir sonraki Istanbul gece yarisi (00:00).
    static func nextMidnight(after d: Date) -> Date {
        return startOfDay(d).addingTimeInterval(24 * 3600)
    }

    /// "{n}" gibi yer tutuculari doldurur (tek yerlestirme, duz metin).
    static func fill(_ template: String, _ pairs: [(String, String)]) -> String {
        var out = template
        for (k, v) in pairs {
            out = out.replacingOccurrences(of: "{" + k + "}", with: v)
        }
        return out
    }
}

// MARK: - Ortak zarf

protocol BuSnapshot: Decodable {
    var schema: Int? { get }
    var state: String? { get }
    var expiresAt: String? { get }
    var lang: String? { get }
    var rtl: Bool? { get }
    var deepLink: String? { get }
    var a11y: String? { get }
    var strings: [String: String]? { get }
}

extension BuSnapshot {
    func str(_ key: String) -> String { return strings?[key] ?? "" }
}

struct BuMeta: Decodable {
    let schema: Int?
    let updatedAt: String?
    let lang: String?
    let rtl: Bool?
    let signedIn: Bool?
    let strings: [String: String]?
}

// MARK: - Slug modelleri

struct BuMenuItem: Decodable {
    let name: String?
    let kcal: Int?
    let kcalText: String?
}

struct BuMenuMeal: Decodable {
    let id: String?
    let label: String?
    let items: [BuMenuItem]?
    let totalKcal: Int?
    let totalText: String?
}

struct BuMenuSmall: Decodable {
    let caption: String?
    let main: String?
    let sub: String?
    let kcalLine: String?
}

/// Bir gunun menusu (ust duzey = bugun, `upcoming[i]` = sonraki gunler; ayni bicim).
struct BuMenuDay: Decodable {
    let date: String?
    let dateLabel: String?
    let empty: Bool?
    let meals: [BuMenuMeal]?
    let totalKcal: Int?
    let totalText: String?
    let totalLine: String?
    let kcalComplete: Bool?
    let small: BuMenuSmall?
}

struct BuMenuSnap: BuSnapshot {
    let schema: Int?
    let state: String?
    let expiresAt: String?
    let lang: String?
    let rtl: Bool?
    let deepLink: String?
    let a11y: String?
    let strings: [String: String]?
    let date: String?
    let dateLabel: String?
    let empty: Bool?
    let meals: [BuMenuMeal]?
    let totalKcal: Int?
    let totalText: String?
    let totalLine: String?
    let kcalComplete: Bool?
    let small: BuMenuSmall?
    let upcoming: [BuMenuDay]?

    var topDay: BuMenuDay {
        return BuMenuDay(date: date, dateLabel: dateLabel, empty: empty, meals: meals, totalKcal: totalKcal,
                         totalText: totalText, totalLine: totalLine, kcalComplete: kcalComplete, small: small)
    }

    /// Yerel Istanbul gunune esit `date` tasiyan nesne; yoksa nil (-> bos durum).
    func day(for now: Date) -> BuMenuDay? {
        let today = BuTime.dayString(now)
        if topDay.date == today { return topDay }
        for d in upcoming ?? [] where d.date == today { return d }
        return nil
    }
}

struct BuLesson: Decodable {
    let start: String?
    let end: String?
    let startMin: Int?
    let endMin: Int?
    let title: String?
    let room: String?
}

struct BuTimetableDay: Decodable {
    let date: String?
    let dateLabel: String?
    let dayName: String?
    let count: Int?
    let lessons: [BuLesson]?
}

struct BuTimetableNext: Decodable {
    let date: String?
    let time: String?
    let dayName: String?
    let dayShort: String?
    let labelFull: String?
    let labelShort: String?
}

struct BuTimetableSnap: BuSnapshot {
    let schema: Int?
    let state: String?
    let expiresAt: String?
    let lang: String?
    let rtl: Bool?
    let deepLink: String?
    let a11y: String?
    let strings: [String: String]?
    let date: String?
    let dateLabel: String?
    let dayName: String?
    let count: Int?
    let lessons: [BuLesson]?
    let next: BuTimetableNext?
    let upcoming: [BuTimetableDay]?

    var topDay: BuTimetableDay {
        return BuTimetableDay(date: date, dateLabel: dateLabel, dayName: dayName, count: count, lessons: lessons)
    }

    /// Tum gunler (bugun + sonraki 6 takvim gunu), tarih sirasiyla.
    var allDays: [BuTimetableDay] { return [topDay] + (upcoming ?? []) }
}

struct BuEventItem: Decodable {
    let title: String?
    let communityName: String?
    let startsAt: String?
    let day: String?
    let monthCaps: String?
    let timeLabel: String?
    let venue: String?
    let deepLink: String?
}

struct BuEventsSnap: BuSnapshot {
    let schema: Int?
    let state: String?
    let expiresAt: String?
    let lang: String?
    let rtl: Bool?
    let deepLink: String?
    let a11y: String?
    let strings: [String: String]?
    let count: Int?
    let countLabel: String?
    let events: [BuEventItem]?

    /// `startsAt < simdi - 1 saat` satirlarini eler (liste uygulamada bayat olabilir). startsAt bozuksa satir tutulur.
    func upcoming(at now: Date) -> [BuEventItem] {
        let limit = now.addingTimeInterval(-3600)
        return (events ?? []).filter { e in
            if let d = BuTime.parseISO(e.startsAt) { return d >= limit }
            return true
        }
    }
}

struct BuAnnouncementItem: Decodable {
    let title: String?
    let sourceName: String?
    let dateLabel: String?
    let urgent: Bool?
    let urgentLabel: String?
    let metaText: String?
    let deepLink: String?
}

struct BuAnnouncementsSnap: BuSnapshot {
    let schema: Int?
    let state: String?
    let expiresAt: String?
    let lang: String?
    let rtl: Bool?
    let deepLink: String?
    let a11y: String?
    let strings: [String: String]?
    let count: Int?
    let lastLabel: String?
    let items: [BuAnnouncementItem]?
}

struct BuPollOption: Decodable {
    let label: String?
    let percent: Int?
    let percentText: String?
}

struct BuPollSnap: BuSnapshot {
    let schema: Int?
    let state: String?
    let expiresAt: String?
    let lang: String?
    let rtl: Bool?
    let deepLink: String?
    let a11y: String?
    let strings: [String: String]?
    let question: String?
    let userVoted: Bool?
    let resultsVisible: Bool?
    let totalVotesLabel: String?
    let microLine: String?
    let secretLine: String?
    let leaderIndex: Int?
    let options: [BuPollOption]?
}

struct BuQuickItem: Decodable {
    let id: String?
    let icon: String?
    let label: String?
    let a11yLabel: String?
    let deepLink: String?
}

struct BuQuickSnap: BuSnapshot {
    let schema: Int?
    let state: String?
    let expiresAt: String?
    let lang: String?
    let rtl: Bool?
    let deepLink: String?
    let a11y: String?
    let strings: [String: String]?
    let smallIds: [String]?
    let items: [BuQuickItem]?
}

struct BuSocialLinks: Decodable {
    let messages: String?
    let notifications: String?
    let likes: String?
    let header: String?
}

struct BuSocialSnap: BuSnapshot {
    let schema: Int?
    let state: String?
    let expiresAt: String?
    let lang: String?
    let rtl: Bool?
    let deepLink: String?
    let a11y: String?
    let strings: [String: String]?
    let unreadMessages: Int?
    let newNotifications: Int?
    let newLikesAndFollowers: Int?
    let unreadMessagesText: String?
    let newNotificationsText: String?
    let newLikesAndFollowersText: String?
    let allZero: Bool?
    let links: BuSocialLinks?
}

// MARK: - Baglam, durum, giris

/// Dil/yon + oturumsuz metinler (meta'dan; meta yoksa cihaz dili + yerel Localizable.strings).
struct BuContext {
    let lang: String
    let rtl: Bool
    let signedOutTitle: String
    let signedOutSub: String

    static func make(meta: BuMeta?, snapshotLang: String? = nil, snapshotRtl: Bool? = nil) -> BuContext {
        let device = deviceLang()
        let lang = meta?.lang ?? snapshotLang ?? device
        let rtl = meta?.rtl ?? snapshotRtl ?? (lang == "ar")
        let title = nonEmpty(meta?.strings?["signedOutTitle"]) ?? NSLocalizedString("signedout.title", comment: "")
        let sub = nonEmpty(meta?.strings?["signedOutSub"]) ?? NSLocalizedString("signedout.sub", comment: "")
        return BuContext(lang: lang, rtl: rtl, signedOutTitle: title, signedOutSub: sub)
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s = s, !s.isEmpty else { return nil }
        return s
    }

    static func deviceLang() -> String {
        let first = Locale.preferredLanguages.first ?? "tr"
        if first.hasPrefix("ar") { return "ar" }
        if first.hasPrefix("en") { return "en" }
        return "tr"
    }
}

enum BuState<S> {
    case data(S)
    case empty(S)
    case signedOut
}

struct BuEntry<S: BuSnapshot>: TimelineEntry {
    let date: Date
    let state: BuState<S>
    let ctx: BuContext
}

// MARK: - Yukleme

enum BuStore {
    static var defaults: UserDefaults? { return UserDefaults(suiteName: BuWidgetTokens.appGroup) }

    static func raw(_ key: String) -> String? {
        guard let s = defaults?.string(forKey: key), !s.isEmpty else { return nil }
        return s
    }

    static func decode<T: Decodable>(_ type: T.Type, json: String) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func loadMeta() -> BuMeta? {
        guard let s = raw(BuWidgetTokens.keyMeta) else { return nil }
        return decode(BuMeta.self, json: s)
    }

    static func load<S: BuSnapshot>(_ type: S.Type, key: String) -> S? {
        guard let s = raw(key) else { return nil }
        return decode(S.self, json: s)
    }
}

enum BuResolver {
    /// Durum kurali (DATA_CONTRACT bolum 7): oturum yok/bozuk/schema>1 -> oturumsuz; state empty ya da
    /// `at > expiresAt` -> bos durum. `ignoreExpiry` galeri ornegi icindir.
    static func state<S: BuSnapshot>(snapshot: S?, meta: BuMeta?, at date: Date, ignoreExpiry: Bool = false) -> BuState<S> {
        if let m = meta {
            if m.signedIn == false { return .signedOut }
            if (m.schema ?? 1) > 1 { return .signedOut }
        }
        guard let snap = snapshot else { return .signedOut }
        if (snap.schema ?? 1) > 1 { return .signedOut }
        if snap.state == "signedOut" { return .signedOut }
        if snap.state == "empty" { return .empty(snap) }
        if !ignoreExpiry, let exp = BuTime.parseISO(snap.expiresAt), date > exp { return .empty(snap) }
        return .data(snap)
    }
}

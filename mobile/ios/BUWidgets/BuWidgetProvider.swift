// BuWidgetProvider.swift
// Tek genel TimelineProvider: snapshot'i App Group UserDefaults'tan okur, zaman cizelgesi girisleri uretir
// (gece yarisi, ders gecisleri, etkinlik eleme, bayatlik) ve `.after(30 dk)` ile yeniden ister.
// Galeri onizlemesi / placeholder = tasarimdaki ornek icerik (BuSampleData). Ag istegi YOK.

import SwiftUI
import WidgetKit

struct BuProvider<S: BuSnapshot>: TimelineProvider {
    typealias Entry = BuEntry<S>

    /// App Group anahtari (bu_widget_<slug>).
    let key: String
    /// Galeri ornegi (BuSampleData.<slug>).
    let sampleJSON: String
    /// Slug'a ozgu ek zaman cizelgesi giris noktalari (simdiden sonra).
    let extraDates: (S, Date) -> [Date]

    private static var refreshInterval: TimeInterval { return 30 * 60 }
    private static var maxEntries: Int { return 24 }
    private static var horizon: TimeInterval { return 8 * 24 * 3600 }

    func placeholder(in context: Context) -> BuEntry<S> {
        return sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (BuEntry<S>) -> Void) {
        if context.isPreview {
            completion(sampleEntry())
            return
        }
        completion(entries(now: Date()).first ?? signedOutEntry(Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BuEntry<S>>) -> Void) {
        let now = Date()
        let list = entries(now: now)
        completion(Timeline(entries: list, policy: .after(now.addingTimeInterval(BuProvider.refreshInterval))))
    }

    // MARK: Girisler

    private func entries(now: Date) -> [BuEntry<S>] {
        let meta = BuStore.loadMeta()
        let snap = BuStore.load(S.self, key: key)
        let ctx = BuContext.make(meta: meta, snapshotLang: snap?.lang, snapshotRtl: snap?.rtl)

        var dates: [Date] = [now]
        if let snap = snap, case .signedOut = BuResolver.state(snapshot: snap, meta: meta, at: now) {
            // oturumsuzda tek giris yeter
        } else if let snap = snap {
            var extra = extraDates(snap, now)
            if let exp = BuTime.parseISO(snap.expiresAt), exp > now { extra.append(exp) }
            extra.append(BuTime.nextMidnight(after: now))
            let limit = now.addingTimeInterval(BuProvider.horizon)
            dates += extra.filter { $0 > now && $0 <= limit }
        }
        dates.sort()
        var unique: [Date] = []
        for d in dates {
            if let last = unique.last, abs(d.timeIntervalSince(last)) < 1 { continue }
            unique.append(d)
        }
        if unique.count > BuProvider.maxEntries { unique = Array(unique.prefix(BuProvider.maxEntries)) }
        return unique.map { d in
            BuEntry(date: d, state: BuResolver.state(snapshot: snap, meta: meta, at: d), ctx: ctx)
        }
    }

    private func signedOutEntry(_ date: Date) -> BuEntry<S> {
        return BuEntry(date: date, state: .signedOut, ctx: BuContext.make(meta: BuStore.loadMeta()))
    }

    private func sampleEntry() -> BuEntry<S> {
        let meta = BuStore.decode(BuMeta.self, json: BuSampleData.meta)
        let snap = BuStore.decode(S.self, json: sampleJSON)
        let now = BuSampleData.sampleNow
        return BuEntry(date: now,
                       state: BuResolver.state(snapshot: snap, meta: meta, at: now, ignoreExpiry: true),
                       ctx: BuContext.make(meta: meta, snapshotLang: snap?.lang, snapshotRtl: snap?.rtl))
    }
}

// MARK: - Slug'a ozgu ek giris noktalari

enum BuTimeline {
    static func noExtra<S>(_ snap: S, _ now: Date) -> [Date] { return [] }

    /// Menu: bugun 12:00 ve 18:00 (sozlesme) + sonraki iki gece yarisi.
    static func menu(_ snap: BuMenuSnap, _ now: Date) -> [Date] {
        var out: [Date] = [BuTime.date(onDayOf: now, minutes: 12 * 60), BuTime.date(onDayOf: now, minutes: 18 * 60)]
        let m1 = BuTime.nextMidnight(after: now)
        out.append(m1)
        out.append(m1.addingTimeInterval(24 * 3600))
        return out
    }

    /// Ders: bugunun her ders baslangic/bitisi + gece yarisi (+ 00:05).
    static func timetable(_ snap: BuTimetableSnap, _ now: Date) -> [Date] {
        var out: [Date] = []
        let today = BuTime.dayString(now)
        for day in snap.allDays where day.date == today {
            for l in day.lessons ?? [] {
                if let s = l.startMin { out.append(BuTime.date(onDayOf: now, minutes: s)) }
                if let e = l.endMin { out.append(BuTime.date(onDayOf: now, minutes: e)) }
            }
        }
        let m = BuTime.nextMidnight(after: now)
        out.append(m)
        out.append(m.addingTimeInterval(5 * 60))
        return out
    }

    /// Etkinlik: her etkinligin baslangic + 1 saat (satir elenir) ve gece yarisi.
    static func events(_ snap: BuEventsSnap, _ now: Date) -> [Date] {
        var out: [Date] = []
        for e in snap.events ?? [] {
            if let d = BuTime.parseISO(e.startsAt) { out.append(d.addingTimeInterval(3600)) }
        }
        out.append(BuTime.nextMidnight(after: now))
        return out
    }
}

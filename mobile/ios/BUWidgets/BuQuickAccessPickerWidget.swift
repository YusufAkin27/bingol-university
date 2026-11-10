// BuQuickAccessPickerWidget.swift
// Secilebilir Hizli Erisim (iOS 17+, kind BUQuickAccessPickerWidget): kullanici widget'i duzenleyerek (App Intents)
// hangi kisayollarin hangi sirayla gorunecegini secer. Mevcut statik BUQuickAccessWidget AYNEN kalir (iOS 15-16 ve
// onceden eklenmis widget'lar); bu widget ayri bir giris olarak yalniz iOS 17+ icin galeride gorunur.
// Gizlilik: intent yalniz 8 sabit kisayol kimligi tutar (kisisel veri yok); secimi sistem widget'a ozel saklar
// (cihaza ozel). Oturum kapaninca icerik zaten "Giris yap"a doner (snapshot meta); secim hesaptan bagimsiz tercihtir.
// Gorunum: BuQuickAccessView yeniden kullanilir (snapshot ogeleri secime gore suzulur).
// NOT: Windows'ta DERLENEMEZ; macOS/Xcode 15+ ile dogrulanmalidir.

import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
enum BuShortcutOption: String, AppEnum {
    case menu, timetable, events, clubs, chat, qr, news, search

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: "widget.quickaccess.shortcut")
    }

    static var caseDisplayRepresentations: [BuShortcutOption: DisplayRepresentation] {
        return [
            .menu: DisplayRepresentation(title: "widget.quickaccess.q.menu"),
            .timetable: DisplayRepresentation(title: "widget.quickaccess.q.timetable"),
            .events: DisplayRepresentation(title: "widget.quickaccess.q.events"),
            .clubs: DisplayRepresentation(title: "widget.quickaccess.q.clubs"),
            .chat: DisplayRepresentation(title: "widget.quickaccess.q.chat"),
            .qr: DisplayRepresentation(title: "widget.quickaccess.q.qr"),
            .news: DisplayRepresentation(title: "widget.quickaccess.q.news"),
            .search: DisplayRepresentation(title: "widget.quickaccess.q.search"),
        ]
    }
}

@available(iOS 17.0, *)
struct BuQuickAccessIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { return "widget.quickaccess.configure.title" }
    static var description: IntentDescription { return IntentDescription("widget.quickaccess.configure.desc") }

    /// Bos/nil = hepsi (varsayilan 8'li liste). Dizi sirasi = gorunum sirasi.
    @Parameter(title: "widget.quickaccess.shortcuts")
    var shortcuts: [BuShortcutOption]?
}

@available(iOS 17.0, *)
struct BuQuickPickerProvider: AppIntentTimelineProvider {
    typealias Entry = BuEntry<BuQuickSnap>
    typealias Intent = BuQuickAccessIntent

    private let base = BuProvider<BuQuickSnap>(
        key: BuWidgetTokens.keyQuickAccess,
        sampleJSON: BuSampleData.quickaccess,
        extraDates: BuTimeline.noExtra
    )

    func placeholder(in context: Context) -> Entry {
        return base.placeholder(in: context)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        let entry: Entry = await withCheckedContinuation { cont in
            base.getSnapshot(in: context) { cont.resume(returning: $0) }
        }
        return BuQuickPickerProvider.restrict(entry, ids: configuration.shortcuts)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let tl: Timeline<Entry> = await withCheckedContinuation { cont in
            base.getTimeline(in: context) { cont.resume(returning: $0) }
        }
        return Timeline(
            entries: tl.entries.map { BuQuickPickerProvider.restrict($0, ids: configuration.shortcuts) },
            policy: tl.policy
        )
    }

    /// Snapshot ogelerini secime gore suzer ve secim sirasina dizer; secim bos ya da eslesmiyorsa dokunmaz.
    static func restrict(_ entry: Entry, ids: [BuShortcutOption]?) -> Entry {
        guard let ids = ids, !ids.isEmpty else { return entry }
        switch entry.state {
        case .data(let s):
            return BuEntry(date: entry.date, state: .data(restrict(s, ids: ids)), ctx: entry.ctx)
        case .empty(let s):
            return BuEntry(date: entry.date, state: .empty(restrict(s, ids: ids)), ctx: entry.ctx)
        case .signedOut:
            return entry
        }
    }

    private static func restrict(_ s: BuQuickSnap, ids: [BuShortcutOption]) -> BuQuickSnap {
        let all = s.items ?? []
        var picked: [BuQuickItem] = []
        for o in ids {
            if let it = all.first(where: { $0.id == o.rawValue }), !picked.contains(where: { $0.id == it.id }) {
                picked.append(it)
            }
        }
        if picked.isEmpty { return s }
        return BuQuickSnap(
            schema: s.schema, state: s.state, expiresAt: s.expiresAt, lang: s.lang, rtl: s.rtl,
            deepLink: s.deepLink, a11y: s.a11y, strings: s.strings,
            smallIds: Array(picked.prefix(BuWidgetTokens.quickSmallTiles)).compactMap { $0.id },
            items: picked
        )
    }
}

@available(iOS 17.0, *)
struct BUQuickAccessPickerWidget: Widget {
    let kind: String = "BUQuickAccessPickerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: BuQuickAccessIntent.self, provider: BuQuickPickerProvider()) { entry in
            BuQuickAccessView(entry: entry)
        }
        .configurationDisplayName("widget.quickaccess.picker.name")
        .description("widget.quickaccess.picker.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

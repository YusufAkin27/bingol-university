// BuTimetableWidget.swift
// Ders Programim (kind BUTimetableWidget). Dokununca bukampus://timetable. Tasarim: design/widget-previews/timetable/README.md
// Durum (yerel Istanbul saati nowMin): endMin <= nowMin gecmis (opaklik 0.5); startMin <= nowMin < endMin "Su an";
// ilk startMin > nowMin siradaki. Zaman cizelgesi her ders baslangic/bitisinde giris uretir (BuTimeline.timetable).

import SwiftUI
import WidgetKit

/// Bir giris tarihi icin ders durumu.
private struct BuTimetableModel {
    let day: BuTimetableDay?
    let lessons: [BuLesson]
    let nowMin: Int
    let currentIdx: Int?
    let nextIdx: Int?

    var activeIdx: Int? { return currentIdx ?? nextIdx }

    init(snap: BuTimetableSnap, now: Date) {
        let today = BuTime.dayString(now)
        let d = snap.allDays.first(where: { $0.date == today })
        let ls = d?.lessons ?? []
        let nm = BuTime.minutes(now)
        var cur: Int? = nil
        var nxt: Int? = nil
        for (i, l) in ls.enumerated() {
            let s = l.startMin ?? Int.max
            let e = l.endMin ?? Int.max
            if cur == nil, s <= nm, nm < e { cur = i }
            if nxt == nil, s > nm { nxt = i }
        }
        day = d
        lessons = ls
        nowMin = nm
        currentIdx = cur
        nextIdx = nxt
    }

    func isPast(_ l: BuLesson) -> Bool {
        guard let e = l.endMin else { return false }
        return e <= nowMin
    }

    /// Kalan sure metni (inMin / inHour); gecmis/yoksa nil.
    func remaining(_ l: BuLesson, _ snap: BuTimetableSnap) -> String? {
        guard let s = l.startMin else { return nil }
        let d = s - nowMin
        if d <= 0 { return nil }
        if d < 60 { return BuTime.fill(snap.str("inMin"), [("n", String(d))]) }
        return BuTime.fill(snap.str("inHour"), [("n", String(max(1, d / 60)))])
    }

    /// Gorunen pencerenin baslangici: aktif dersten baslar, sona dogru tasarsa geri kayar.
    func window(rows n: Int) -> Range<Int> {
        let total = lessons.count
        if total == 0 { return 0..<0 }
        let start = min(activeIdx ?? 0, max(0, total - n))
        return start..<min(total, start + n)
    }

    /// Siradaki ders etiketi (bos durum alt metni): once snapshot.next (gecerliyse), yoksa sonraki gunlerden hesap.
    func nextLabel(snap: BuTimetableSnap, now: Date, short: Bool) -> String? {
        let today = BuTime.dayString(now)
        if let n = snap.next, let nd = n.date {
            var valid = nd > today
            if nd == today, let t = n.time, let m = BuTimetableModel.minutes(of: t), m > nowMin { valid = true }
            if valid {
                let label = short ? n.labelShort : n.labelFull
                if let label = label, !label.isEmpty { return label }
            }
        }
        for d in snap.allDays {
            guard let dd = d.date, dd > today, let first = (d.lessons ?? []).first, let st = first.start else { continue }
            let name = d.dayName ?? ""
            return (short ? String(name.prefix(3)) : name) + " " + st
        }
        return nil
    }

    static func minutes(of hhmm: String) -> Int? {
        let p = hhmm.split(separator: ":")
        guard p.count == 2, let h = Int(p[0]), let m = Int(p[1]) else { return nil }
        return h * 60 + m
    }
}

struct BuTimetableView: View {
    let entry: BuEntry<BuTimetableSnap>
    @Environment(\.widgetFamily) private var family

    var body: some View {
        BuFrame(ctx: entry.ctx, link: buLink(entry.state)) { theme in
            content(theme)
        }
    }

    @ViewBuilder
    private func content(_ t: BuTheme) -> some View {
        switch entry.state {
        case .signedOut:
            BuSignedOutView(ctx: entry.ctx, theme: t)
        case .empty(let snap):
            emptyView(snap, BuTimetableModel(snap: snap, now: entry.date), t)
        case .data(let snap):
            let model = BuTimetableModel(snap: snap, now: entry.date)
            if model.activeIdx != nil {
                dataView(snap, model, t)
                    .buA11y(snap.a11y)
            } else {
                emptyView(snap, model, t)
            }
        }
    }

    // MARK: Bos durum

    @ViewBuilder
    private func emptyView(_ snap: BuTimetableSnap, _ m: BuTimetableModel, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        if family.isSmall {
            let label = m.nextLabel(snap: snap, now: entry.date, short: true)
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "clock", caption: snap.str("captionNone"))
                BuEmptyLeading(theme: t, lang: lang, title: snap.str("emptyTitle"), titleLines: 2,
                               sub: label.map { BuTime.fill(snap.str("nextSmall"), [("day", $0)]) },
                               subRole: BuWidgetTokens.small, subColor: t.text3)
            }
        } else {
            let label = m.nextLabel(snap: snap, now: entry.date, short: false)
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "clock", caption: snap.str("captionFull"))
                BuEmptyLeading(theme: t, lang: lang, title: snap.str("emptyTitle"), titleLines: 1,
                               sub: label.map { BuTime.fill(snap.str("nextFull"), [("day", $0)]) },
                               subRole: BuWidgetTokens.body, subColor: t.text2)
            }
        }
    }

    // MARK: Veri

    @ViewBuilder
    private func dataView(_ snap: BuTimetableSnap, _ m: BuTimetableModel, _ t: BuTheme) -> some View {
        switch family {
        case .systemSmall:
            smallView(snap, m, t)
        case .systemMedium:
            mediumView(snap, m, t)
        default:
            largeView(snap, m, t)
        }
    }

    private func badge(_ text: String, _ t: BuTheme, width: CGFloat? = nil) -> some View {
        let lang = entry.ctx.lang
        return BuLabel(text: text, role: BuWidgetTokens.body, color: t.inverseFg, lang: lang)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, BuWidgetTokens.s2)
            .padding(.horizontal, BuWidgetTokens.s8)
            .frame(width: width)
            .background(RoundedRectangle(cornerRadius: BuWidgetTokens.radiusBadgeSmall, style: .continuous).fill(t.inverseBg))
    }

    private func smallView(_ snap: BuTimetableSnap, _ m: BuTimetableModel, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let idx = m.activeIdx ?? 0
        let l = m.lessons[idx]
        let isCurrent = m.currentIdx != nil
        let badgeText = isCurrent ? snap.str("nowBadge") : (l.start ?? "")
        let side: String? = isCurrent
            ? BuTime.fill(snap.str("endsAt"), [("time", l.end ?? "")])
            : m.remaining(l, snap)
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "clock", caption: snap.str("captionNext"))
            HStack(spacing: BuWidgetTokens.s8) {
                badge(badgeText, t)
                if let s = side {
                    BuLabel(text: s, role: BuWidgetTokens.small, color: t.text3, lang: lang)
                }
            }
            BuLabel(text: l.title ?? "", role: BuWidgetTokens.title, color: t.text1,
                    lines: BuWidgetTokens.timetableSmallTitleLines, lang: lang)
                .padding(.top, BuWidgetTokens.s8)
            Spacer(minLength: 0)
            if let room = l.room, !room.isEmpty {
                HStack(spacing: BuWidgetTokens.s4) {
                    BuIcon(name: "map-pin", size: BuWidgetTokens.iconMeta, color: t.text2)
                    BuLabel(text: room, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                }
            }
        }
    }

    private func lessonRow(_ l: BuLesson, active: Bool, past: Bool, height: CGFloat, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return HStack(spacing: BuWidgetTokens.s8) {
            if active {
                badge(l.start ?? "", t, width: BuWidgetTokens.badgeTimetableWidth)
            } else {
                BuLabel(text: l.start ?? "", role: BuWidgetTokens.body, color: past ? t.text2 : t.text1,
                        lang: lang, align: .center)
                    .frame(width: BuWidgetTokens.badgeTimetableWidth)
            }
            BuLabel(text: l.title ?? "", role: BuWidgetTokens.body, color: t.text1, lang: lang)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let room = l.room, !room.isEmpty {
                HStack(spacing: BuWidgetTokens.s4) {
                    BuIcon(name: "map-pin", size: BuWidgetTokens.iconMeta, color: t.text2)
                    BuLabel(text: room, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.horizontal, BuWidgetTokens.s8)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: BuWidgetTokens.radiusRow, style: .continuous)
                .fill(active ? t.chip : Color.clear)
        )
        .opacity(past ? BuWidgetTokens.opacityPastLesson : 1)
    }

    private func rowsView(_ m: BuTimetableModel, cap: Int, rowHeight: CGFloat, gap: CGFloat, _ t: BuTheme) -> some View {
        return GeometryReader { g in
            let n = BuFit.rows(available: g.size.height, row: rowHeight, gap: gap, cap: cap)
            let range = m.window(rows: n)
            VStack(alignment: .leading, spacing: gap) {
                ForEach(Array(range), id: \.self) { i in
                    lessonRow(m.lessons[i], active: i == m.activeIdx, past: m.isPast(m.lessons[i]),
                              height: rowHeight, t)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity)
    }

    private func mediumView(_ snap: BuTimetableSnap, _ m: BuTimetableModel, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let header = BuTime.fill(snap.str("headerNext"), [("date", m.day?.dateLabel ?? snap.dateLabel ?? "")])
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "clock", caption: header)
            rowsView(m, cap: BuWidgetTokens.timetableMediumRows, rowHeight: BuWidgetTokens.rowTimetableMedium,
                     gap: BuWidgetTokens.s4, t)
        }
    }

    private func largeView(_ snap: BuTimetableSnap, _ m: BuTimetableModel, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let cap = BuWidgetTokens.timetableLargeRows
        let total = m.lessons.count
        let range = m.window(rows: cap)
        let hiddenAfter = max(0, total - range.upperBound)
        let count = m.day?.count ?? total
        let activeLesson = m.lessons[m.activeIdx ?? 0]
        let side: String? = m.currentIdx != nil ? snap.str("nowBadge") : m.remaining(activeLesson, snap)
        let note: String? = {
            if hiddenAfter > 0 { return BuTime.fill(snap.str("more"), [("n", String(hiddenAfter))]) }
            if let last = m.lessons.last?.end { return BuTime.fill(snap.str("lastEnds"), [("time", last)]) }
            return nil
        }()
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "calendar", caption: m.day?.dateLabel ?? snap.dateLabel ?? "")
            HStack(alignment: .firstTextBaseline, spacing: BuWidgetTokens.s8) {
                BuLabel(text: BuTime.fill(snap.str("todayCount"), [("n", String(count))]),
                        role: BuWidgetTokens.title, color: t.text1, lang: lang)
                Spacer(minLength: BuWidgetTokens.s4)
                if let s = side {
                    BuLabel(text: s, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                }
            }
            .padding(.bottom, BuWidgetTokens.s12)
            rowsView(m, cap: cap, rowHeight: BuWidgetTokens.rowTimetableLarge, gap: BuWidgetTokens.s6, t)
            if let n = note {
                BuLabel(text: n, role: BuWidgetTokens.small, color: t.text3, lang: lang)
            }
        }
    }
}

struct BUTimetableWidget: Widget {
    let kind: String = "BUTimetableWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BuProvider<BuTimetableSnap>(key: BuWidgetTokens.keyTimetable,
                                                  sampleJSON: BuSampleData.timetable,
                                                  extraDates: BuTimeline.timetable)
        ) { entry in
            BuTimetableView(entry: entry)
        }
        .configurationDisplayName("widget.timetable.name")
        .description("widget.timetable.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

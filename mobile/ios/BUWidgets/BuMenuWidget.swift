// BuMenuWidget.swift
// Gunun Yemek Menusu (kind BUMenuWidget). Dokununca bukampus://menu. Tasarim: design/widget-previews/menu/README.md

import SwiftUI
import WidgetKit

struct BuMenuView: View {
    let entry: BuEntry<BuMenuSnap>
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
            emptyView(snap, t)
        case .data(let snap):
            if let day = snap.day(for: entry.date), hasDishes(day) {
                dataView(snap, day, t)
                    .buA11y(snap.a11y)
            } else {
                emptyView(snap, t)
            }
        }
    }

    private func hasDishes(_ day: BuMenuDay) -> Bool {
        if day.empty == true { return false }
        for m in day.meals ?? [] where !(m.items ?? []).isEmpty { return true }
        return false
    }

    private func mealIcon(_ m: BuMenuMeal) -> String {
        return m.id == "dinner" ? "moon" : "sun"
    }

    // MARK: Bos durum

    @ViewBuilder
    private func emptyView(_ snap: BuMenuSnap, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        if family.isSmall {
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "utensils", caption: snap.str("captionAny"))
                BuEmptyLeading(theme: t, lang: lang, title: snap.str("emptyTitle"), titleLines: 2,
                               sub: snap.str("emptySmallSub"), subRole: BuWidgetTokens.small, subColor: t.text3)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "utensils", caption: snap.str("captionFull"))
                BuEmptyLeading(theme: t, lang: lang, title: snap.str("emptyTitle"), titleLines: 1,
                               sub: snap.str("emptySub"), subRole: BuWidgetTokens.body, subColor: t.text2)
            }
        }
    }

    // MARK: Veri

    @ViewBuilder
    private func dataView(_ snap: BuMenuSnap, _ day: BuMenuDay, _ t: BuTheme) -> some View {
        switch family {
        case .systemSmall:
            smallView(snap, day, t)
        case .systemMedium:
            mediumView(snap, day, t)
        default:
            largeView(snap, day, t)
        }
    }

    private func allItems(_ day: BuMenuDay) -> [BuMenuItem] {
        var out: [BuMenuItem] = []
        for m in day.meals ?? [] { out += (m.items ?? []) }
        return out
    }

    /// "1.570 kcal" -> "1.570" (kcalToday sablonundaki {kcal} birimsizdir).
    private func kcalNumber(_ text: String?, unit: String) -> String? {
        guard var s = text, !s.isEmpty else { return nil }
        if !unit.isEmpty, s.hasSuffix(" " + unit) { s = String(s.dropLast(unit.count + 1)) }
        return s
    }

    private func smallView(_ snap: BuMenuSnap, _ day: BuMenuDay, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let items = allItems(day)
        let main = day.small?.main ?? items.first?.name ?? ""
        let sub: String = {
            if let s = day.small?.sub { return s }
            return items.dropFirst().prefix(3).compactMap { $0.name }.joined(separator: " \u{00B7} ")
        }()
        let kcalLine: String? = {
            if let k = day.small?.kcalLine, !k.isEmpty { return k }
            if let n = kcalNumber(day.totalText, unit: snap.str("kcalUnit")) {
                return BuTime.fill(snap.str("kcalToday"), [("kcal", n)])
            }
            return nil
        }()
        let caption = day.small?.caption ?? snap.str("caption")
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "sun", caption: caption)
            BuLabel(text: main, role: BuWidgetTokens.display, color: t.text1,
                    lines: BuWidgetTokens.menuSmallMainLines, lang: lang)
            if !sub.isEmpty {
                BuLabel(text: sub, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                    .padding(.top, BuWidgetTokens.s4)
            }
            Spacer(minLength: 0)
            if let k = kcalLine {
                HStack(spacing: BuWidgetTokens.s4) {
                    BuIcon(name: "flame", size: BuWidgetTokens.iconHeader, color: t.text2)
                    BuLabel(text: k, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                }
            }
        }
    }

    private struct Column {
        let icon: String
        let caption: String?
        let items: [BuMenuItem]
    }

    private func columns(_ day: BuMenuDay) -> [Column] {
        let meals = (day.meals ?? []).filter { !($0.items ?? []).isEmpty }
        let per = BuWidgetTokens.menuMediumDishes
        if meals.count >= 2 {
            return meals.prefix(2).map { m in
                Column(icon: mealIcon(m), caption: m.label, items: Array((m.items ?? []).prefix(per)))
            }
        }
        guard let m = meals.first else { return [] }
        let items = m.items ?? []
        var cols = [Column(icon: mealIcon(m), caption: m.label, items: Array(items.prefix(per)))]
        if items.count > per {
            cols.append(Column(icon: mealIcon(m), caption: nil, items: Array(items.dropFirst(per).prefix(per))))
        }
        return cols
    }

    private func columnView(_ c: Column, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return VStack(alignment: .leading, spacing: BuWidgetTokens.s2) {
            if let cap = c.caption {
                HStack(spacing: BuWidgetTokens.s4) {
                    BuIcon(name: c.icon, size: BuWidgetTokens.iconHeader, color: t.text3)
                    BuLabel(text: cap, role: BuWidgetTokens.caption, color: t.text3, lang: lang)
                }
                .frame(height: BuWidgetTokens.iconHeader)
                .padding(.bottom, BuWidgetTokens.s4)
            } else {
                Color.clear
                    .frame(height: BuWidgetTokens.iconHeader)
                    .padding(.bottom, BuWidgetTokens.s4)
            }
            ForEach(Array(c.items.enumerated()), id: \.offset) { pair in
                BuLabel(text: pair.element.name ?? "", role: BuWidgetTokens.body, color: t.text1, lang: lang)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mediumView(_ snap: BuMenuSnap, _ day: BuMenuDay, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let cols = columns(day)
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "utensils", caption: day.dateLabel ?? "", gap: BuWidgetTokens.s8)
            HStack(alignment: .top, spacing: BuWidgetTokens.s16) {
                ForEach(Array(cols.enumerated()), id: \.offset) { pair in
                    if pair.offset > 0 { BuVDivider(theme: t) }
                    columnView(pair.element, t)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let line = day.totalLine, !line.isEmpty {
                HStack(spacing: BuWidgetTokens.s4) {
                    BuIcon(name: "flame", size: BuWidgetTokens.iconHeader, color: t.text2)
                    BuLabel(text: line, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                }
                .padding(.top, BuWidgetTokens.s4)
            }
        }
    }

    private func largeView(_ snap: BuMenuSnap, _ day: BuMenuDay, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let meals = (day.meals ?? []).filter { !($0.items ?? []).isEmpty }
        let cap = meals.count == 1 ? BuWidgetTokens.menuLargeDishesSingleMeal : BuWidgetTokens.menuLargeDishes
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "utensils", caption: day.dateLabel ?? "")
            ForEach(Array(meals.prefix(2).enumerated()), id: \.offset) { pair in
                if pair.offset > 0 {
                    BuDivider(theme: t).padding(.vertical, BuWidgetTokens.s10)
                }
                mealSection(pair.element, cap: cap, snap: snap, t)
            }
            Spacer(minLength: 0)
            if let total = day.totalText, !total.isEmpty {
                HStack(spacing: BuWidgetTokens.s8) {
                    BuIcon(name: "flame", size: BuWidgetTokens.iconMetaLarge, color: t.text1)
                    BuLabel(text: snap.str("dailyTotal"), role: BuWidgetTokens.body, color: t.text1, lang: lang)
                    Spacer(minLength: BuWidgetTokens.s4)
                    BuLabel(text: total, role: BuWidgetTokens.body, color: t.text1, lang: lang)
                }
                .padding(.horizontal, BuWidgetTokens.s12)
                .frame(height: BuWidgetTokens.kcalChipHeight)
                .background(RoundedRectangle(cornerRadius: BuWidgetTokens.radiusChip, style: .continuous).fill(t.chip))
            }
        }
    }

    private func mealSection(_ m: BuMenuMeal, cap: Int, snap: BuMenuSnap, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let items = m.items ?? []
        let shown = Array(items.prefix(cap))
        let hidden = max(0, items.count - cap)
        return VStack(alignment: .leading, spacing: BuWidgetTokens.s2) {
            HStack(spacing: BuWidgetTokens.s4) {
                BuIcon(name: mealIcon(m), size: BuWidgetTokens.iconHeader, color: t.text3)
                BuLabel(text: m.label ?? "", role: BuWidgetTokens.caption, color: t.text3, lang: lang)
                Spacer(minLength: BuWidgetTokens.s4)
                if let tt = m.totalText {
                    BuLabel(text: tt, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                }
            }
            .frame(height: BuWidgetTokens.small.line)
            .padding(.bottom, BuWidgetTokens.s4)
            ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                HStack(spacing: BuWidgetTokens.s8) {
                    BuLabel(text: pair.element.name ?? "", role: BuWidgetTokens.body, color: t.text1, lang: lang)
                    Spacer(minLength: BuWidgetTokens.s4)
                    if let k = pair.element.kcalText {
                        BuLabel(text: k, role: BuWidgetTokens.small, color: t.text3, lang: lang)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            if hidden > 0 {
                BuLabel(text: BuTime.fill(snap.str("more"), [("n", String(hidden))]),
                        role: BuWidgetTokens.small, color: t.text3, lang: lang)
            }
        }
    }
}

struct BUMenuWidget: Widget {
    let kind: String = "BUMenuWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BuProvider<BuMenuSnap>(key: BuWidgetTokens.keyMenu, sampleJSON: BuSampleData.menu,
                                             extraDates: BuTimeline.menu)
        ) { entry in
            BuMenuView(entry: entry)
        }
        .configurationDisplayName("widget.menu.name")
        .description("widget.menu.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

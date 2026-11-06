// BuEventsWidget.swift
// Yaklasan Etkinlikler (kind BUEventsWidget). Dokununca bukampus://events; satir: events[i].deepLink.
// Small'da tek etkinlik oldugu icin tum widget events[0].deepLink acar. Tasarim: design/widget-previews/events/README.md
// startsAt < simdi - 1 saat olan satirlari widget kendisi eler (BuEventsSnap.upcoming).

import SwiftUI
import WidgetKit

/// README'de olup ortak belirtec tablosunda bulunmayan tek yazi rolu (ay etiketi, small; 12/16, +0.08em).
private let buEventMonthSmall = BuWidgetTokens.TextRole(12, 16, tracking: 0.08)

struct BuEventsView: View {
    let entry: BuEntry<BuEventsSnap>
    @Environment(\.widgetFamily) private var family

    private var link: URL? {
        if family.isSmall, case .data(let snap) = entry.state,
           let first = snap.upcoming(at: entry.date).first, let u = BuLink.url(first.deepLink) {
            return u
        }
        return buLink(entry.state)
    }

    var body: some View {
        BuFrame(ctx: entry.ctx, link: link) { theme in
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
            let list = snap.upcoming(at: entry.date)
            if list.isEmpty {
                emptyView(snap, t)
            } else {
                dataView(snap, list, t)
            }
        }
    }

    // MARK: Bos durum

    @ViewBuilder
    private func emptyView(_ snap: BuEventsSnap, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 0) {
                smallHeader(snap.str("captionEmpty"), t)
                BuEmptyCentered(theme: t, lang: lang, icon: "calendar", iconSize: BuWidgetTokens.iconEmptySmall,
                                title: snap.str("emptyTitle"))
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 0) {
                BuLogoTitleHeader(theme: t, lang: lang, title: snap.str("title"))
                BuEmptyCentered(theme: t, lang: lang, icon: "calendar", iconSize: BuWidgetTokens.iconEmptyMedium,
                                title: snap.str("emptyTitle"), sub: snap.str("emptySub"))
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                BuLogoTitleHeader(theme: t, lang: lang, title: snap.str("title"))
                BuEmptyCentered(theme: t, lang: lang, icon: "calendar", iconSize: BuWidgetTokens.iconEmptyLarge,
                                title: snap.str("emptyTitle"), titleRole: BuWidgetTokens.question,
                                sub: snap.str("emptySub"), subRole: BuWidgetTokens.small, subLines: 2)
            }
        }
    }

    private func smallHeader(_ caption: String, _ t: BuTheme) -> some View {
        return HStack(spacing: BuWidgetTokens.s6) {
            BuIcon(name: "calendar", size: BuWidgetTokens.iconHeaderEvents, color: t.text2)
            BuLabel(text: caption, role: BuWidgetTokens.micro, color: t.text2, lang: entry.ctx.lang)
            Spacer(minLength: 0)
        }
        .frame(height: BuWidgetTokens.headerHeight)
    }

    // MARK: Veri

    @ViewBuilder
    private func dataView(_ snap: BuEventsSnap, _ list: [BuEventItem], _ t: BuTheme) -> some View {
        switch family {
        case .systemSmall:
            smallView(snap, list[0], t)
                .buA11y(snap.a11y)
        case .systemMedium:
            mediumView(snap, list, t)
        default:
            largeView(snap, list, t)
        }
    }

    private func smallView(_ snap: BuEventsSnap, _ e: BuEventItem, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return VStack(alignment: .leading, spacing: 0) {
            smallHeader(snap.str("captionSmall"), t)
            HStack(alignment: .lastTextBaseline, spacing: BuWidgetTokens.s6) {
                BuLabel(text: e.day ?? "", role: BuWidgetTokens.eventDayHero, color: t.text1, lang: lang)
                    .fixedSize(horizontal: true, vertical: false)
                BuLabel(text: e.monthCaps ?? "", role: buEventMonthSmall, color: t.text2, lang: lang)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.top, BuWidgetTokens.s10)
            Spacer(minLength: 0)
            BuLabel(text: e.title ?? "", role: BuWidgetTokens.bodyL, color: t.text1, lines: 2, lang: lang)
            if let time = e.timeLabel, !time.isEmpty {
                HStack(spacing: BuWidgetTokens.s4) {
                    BuIcon(name: "clock", size: BuWidgetTokens.iconMeta, color: t.text2)
                    BuLabel(text: time, role: BuWidgetTokens.micro, color: t.text2, lang: lang)
                }
                .padding(.top, BuWidgetTokens.s6)
            }
        }
    }

    private func dateBadge(_ e: BuEventItem, large: Bool, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let side = BuWidgetTokens.rowEvents
        let radius = large ? BuWidgetTokens.radiusBadgeLarge : BuWidgetTokens.radiusBadgeSmall
        return VStack(spacing: large ? BuWidgetTokens.s2 : 1) {
            BuLabel(text: e.day ?? "", role: large ? BuWidgetTokens.badgeDayLarge : BuWidgetTokens.badgeDaySmall,
                    color: t.text1, lang: lang, align: .center)
            BuLabel(text: e.monthCaps ?? "", role: large ? BuWidgetTokens.badgeMonthLarge : BuWidgetTokens.badgeMonthSmall,
                    color: t.text2, lang: lang, align: .center)
        }
        .frame(width: large ? BuWidgetTokens.badgeEventLargeWidth : side,
               height: large ? BuWidgetTokens.badgeEventLargeHeight : side)
        .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(t.badgeFill))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(t.badgeBorder, lineWidth: BuWidgetTokens.borderWidth))
    }

    private func mediumRow(_ e: BuEventItem, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return BuLinkRow(e.deepLink) {
            HStack(spacing: BuWidgetTokens.s10) {
                dateBadge(e, large: false, t)
                VStack(alignment: .leading, spacing: 0) {
                    BuLabel(text: e.title ?? "", role: BuWidgetTokens.body, color: t.text1, lang: lang)
                    BuLabel(text: e.communityName ?? "", role: BuWidgetTokens.micro, color: t.text2, lang: lang)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let time = e.timeLabel, !time.isEmpty {
                    HStack(spacing: BuWidgetTokens.s4) {
                        BuIcon(name: "clock", size: BuWidgetTokens.iconMeta, color: t.text2)
                        BuLabel(text: time, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .frame(height: BuWidgetTokens.rowEvents)
        }
    }

    private func mediumView(_ snap: BuEventsSnap, _ list: [BuEventItem], _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return VStack(alignment: .leading, spacing: 0) {
            BuLogoTitleHeader(theme: t, lang: lang, title: snap.str("title"))
            GeometryReader { g in
                let n = BuFit.rows(available: g.size.height, row: BuWidgetTokens.rowEvents,
                                   gap: BuWidgetTokens.s4, cap: BuWidgetTokens.eventsMedium)
                let shown = Array(list.prefix(n))
                VStack(alignment: .leading, spacing: shown.count >= 3 ? BuWidgetTokens.s4 : BuWidgetTokens.s6) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                        mediumRow(pair.element, t)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func largeRow(_ e: BuEventItem, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return BuLinkRow(e.deepLink) {
            HStack(spacing: BuWidgetTokens.s12) {
                dateBadge(e, large: true, t)
                VStack(alignment: .leading, spacing: 0) {
                    BuLabel(text: e.title ?? "", role: BuWidgetTokens.question, color: t.text1, lang: lang)
                    BuLabel(text: e.communityName ?? "", role: BuWidgetTokens.small, color: t.text2, lang: lang)
                        .padding(.top, 1)
                    HStack(spacing: BuWidgetTokens.s12) {
                        if let time = e.timeLabel, !time.isEmpty {
                            HStack(spacing: BuWidgetTokens.s4) {
                                BuIcon(name: "clock", size: BuWidgetTokens.iconMetaLarge, color: t.text2)
                                BuLabel(text: time, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        if let venue = e.venue, !venue.isEmpty {
                            HStack(spacing: BuWidgetTokens.s4) {
                                BuIcon(name: "map-pin", size: BuWidgetTokens.iconMetaLarge, color: t.text2)
                                BuLabel(text: venue, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                            }
                        }
                    }
                    .padding(.top, BuWidgetTokens.s4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func largeView(_ snap: BuEventsSnap, _ list: [BuEventItem], _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let shown = Array(list.prefix(BuWidgetTokens.eventsLarge))
        let countText = BuTime.fill(snap.str("countLabel"), [("n", String(shown.count))])
        return VStack(alignment: .leading, spacing: 0) {
            BuLogoTitleHeader(theme: t, lang: lang, title: snap.str("title"), trailing: countText,
                              gap: BuWidgetTokens.s12)
            BuDivider(theme: t)
                .padding(.bottom, BuWidgetTokens.s4)
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                    if pair.offset > 0 { BuDivider(theme: t) }
                    largeRow(pair.element, t)
                }
                if shown.count < BuWidgetTokens.eventsLarge {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

struct BUEventsWidget: Widget {
    let kind: String = "BUEventsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BuProvider<BuEventsSnap>(key: BuWidgetTokens.keyEvents, sampleJSON: BuSampleData.events,
                                               extraDates: BuTimeline.events)
        ) { entry in
            BuEventsView(entry: entry)
        }
        .configurationDisplayName("widget.events.name")
        .description("widget.events.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

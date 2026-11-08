// BuAnnouncementsWidget.swift
// Kampus Duyurulari (kind BUAnnouncementsWidget). Dokununca bukampus://news; satir: items[i].deepLink.
// Small'da tek duyuru: tum widget items[0].deepLink. Tasarim: design/widget-previews/announcements/README.md
// Kirmizi YALNIZ acil duyuruda ("Acil" metni ve medium noktasi, `danger` rengi).

import SwiftUI
import WidgetKit

/// Meta satiri: `metaText` hazir gelir ("Acil · Kutuphane · 02 Kas"); acilsa bastaki "Acil" danger renginde.
private struct BuMetaLine: View {
    let item: BuAnnouncementItem
    let theme: BuTheme
    let color: Color
    let lang: String

    var body: some View {
        let meta = item.metaText ?? item.dateLabel ?? ""
        let role = BuWidgetTokens.micro
        let font = Font.system(size: role.size, weight: BuWidgetTokens.fontWeight)
        if item.urgent == true, let label = item.urgentLabel, !label.isEmpty, meta.hasPrefix(label) {
            let rest = String(meta.dropFirst(label.count))
            return AnyView(
                (Text(label).foregroundColor(theme.danger) + Text(rest).foregroundColor(color))
                    .font(font)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(height: role.line, alignment: .leading)
            )
        }
        return AnyView(BuLabel(text: meta, role: role, color: color, lang: lang))
    }
}

struct BuAnnouncementsView: View {
    let entry: BuEntry<BuAnnouncementsSnap>
    /// Sinavlar ve akademik takvim ayni cizimi paylasir; yalniz bos durum/baslik simgesi degisir.
    var icon: String = "megaphone"
    @Environment(\.widgetFamily) private var family

    private var link: URL? {
        if family.isSmall, case .data(let snap) = entry.state,
           let first = (snap.items ?? []).first, let u = BuLink.url(first.deepLink) {
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
            let list = snap.items ?? []
            if list.isEmpty {
                emptyView(snap, t)
            } else {
                dataView(snap, list, t)
            }
        }
    }

    // MARK: Bos durum

    @ViewBuilder
    private func emptyView(_ snap: BuAnnouncementsSnap, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 0) {
                smallHeader(snap.str("titleSmall"), t)
                BuEmptyCentered(theme: t, lang: lang, icon: icon, iconSize: BuWidgetTokens.iconEmptySmall,
                                title: snap.str("emptyTitle"))
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 0) {
                BuLogoTitleHeader(theme: t, lang: lang, title: snap.str("title"))
                BuEmptyCentered(theme: t, lang: lang, icon: icon, iconSize: BuWidgetTokens.iconEmptyMedium,
                                title: snap.str("emptyTitle"), sub: snap.str("emptySub"))
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                BuLogoTitleHeader(theme: t, lang: lang, title: snap.str("title"))
                BuEmptyCentered(theme: t, lang: lang, icon: icon, iconSize: BuWidgetTokens.iconEmptyLarge,
                                title: snap.str("emptyTitle"), titleRole: BuWidgetTokens.question,
                                sub: snap.str("emptySub"), subRole: BuWidgetTokens.small, subLines: 2)
            }
        }
    }

    private func smallHeader(_ caption: String, _ t: BuTheme) -> some View {
        return HStack(spacing: BuWidgetTokens.s6) {
            BuIcon(name: icon, size: BuWidgetTokens.iconHeaderEvents, color: t.text2)
            BuLabel(text: caption, role: BuWidgetTokens.micro, color: t.text2, lang: entry.ctx.lang)
            Spacer(minLength: 0)
        }
        .frame(height: BuWidgetTokens.headerHeight)
        .padding(.bottom, BuWidgetTokens.s10)
    }

    // MARK: Veri

    @ViewBuilder
    private func dataView(_ snap: BuAnnouncementsSnap, _ list: [BuAnnouncementItem], _ t: BuTheme) -> some View {
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

    private func smallView(_ snap: BuAnnouncementsSnap, _ item: BuAnnouncementItem, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return VStack(alignment: .leading, spacing: 0) {
            smallHeader(snap.str("titleSmall"), t)
            BuLabel(text: item.title ?? "", role: BuWidgetTokens.question, color: t.text1,
                    lines: BuWidgetTokens.announcementsSmallTitleLines, lang: lang)
            Spacer(minLength: 0)
            BuMetaLine(item: item, theme: t, color: t.text2, lang: lang)
        }
    }

    private func mediumRow(_ item: BuAnnouncementItem, first: Bool, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let dot: Color = item.urgent == true ? t.danger : (first ? t.text1 : t.dotPassive)
        return BuLinkRow(item.deepLink) {
            HStack(spacing: BuWidgetTokens.s8) {
                Circle().fill(dot).frame(width: BuWidgetTokens.s4, height: BuWidgetTokens.s4)
                VStack(alignment: .leading, spacing: 0) {
                    BuLabel(text: item.title ?? "", role: BuWidgetTokens.body, color: first ? t.text1 : t.text2, lang: lang)
                    BuMetaLine(item: item, theme: t, color: t.text3, lang: lang)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: BuWidgetTokens.rowEvents)
        }
    }

    private func mediumView(_ snap: BuAnnouncementsSnap, _ list: [BuAnnouncementItem], _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return VStack(alignment: .leading, spacing: 0) {
            BuLogoTitleHeader(theme: t, lang: lang, title: snap.str("title"))
            GeometryReader { g in
                let n = BuFit.rows(available: g.size.height, row: BuWidgetTokens.rowEvents,
                                   gap: BuWidgetTokens.s4, cap: BuWidgetTokens.announcementsMedium)
                let shown = Array(list.prefix(n))
                VStack(alignment: .leading, spacing: BuWidgetTokens.s4) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                        mediumRow(pair.element, first: pair.offset == 0, t)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func largeRow(_ item: BuAnnouncementItem, first: Bool, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return BuLinkRow(item.deepLink) {
            VStack(alignment: .leading, spacing: BuWidgetTokens.s2) {
                BuLabel(text: item.title ?? "", role: BuWidgetTokens.bodyL, color: first ? t.text1 : t.text2,
                        lines: BuWidgetTokens.announcementsLargeTitleLines, lang: lang)
                BuMetaLine(item: item, theme: t, color: t.text3, lang: lang)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func largeView(_ snap: BuAnnouncementsSnap, _ list: [BuAnnouncementItem], _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let shown = Array(list.prefix(BuWidgetTokens.announcementsLarge))
        let last = BuTime.fill(snap.str("last"), [("n", String(shown.count))])
        return VStack(alignment: .leading, spacing: 0) {
            BuLogoTitleHeader(theme: t, lang: lang, title: snap.str("title"), trailing: last, gap: BuWidgetTokens.s12)
            BuDivider(theme: t)
                .padding(.bottom, BuWidgetTokens.s4)
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.offset) { pair in
                    if pair.offset > 0 { BuDivider(theme: t) }
                    largeRow(pair.element, first: pair.offset == 0, t)
                }
                if shown.count < BuWidgetTokens.announcementsLarge {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

/// Yaklasan Sinavlar (kind BUExamsWidget): duyuru cizimi, anahtar bu_widget_exams. Dokununca bukampus://exams.
struct BUExamsWidget: Widget {
    let kind: String = "BUExamsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BuProvider<BuAnnouncementsSnap>(key: BuWidgetTokens.keyExams,
                                                      sampleJSON: BuSampleData.exams,
                                                      extraDates: BuTimeline.noExtra)
        ) { entry in
            BuAnnouncementsView(entry: entry, icon: "calendar")
        }
        .configurationDisplayName("widget.exams.name")
        .description("widget.exams.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Akademik Takvim (kind BUAcademicWidget): duyuru cizimi, anahtar bu_widget_academic. Dokununca bukampus://academic.
struct BUAcademicWidget: Widget {
    let kind: String = "BUAcademicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BuProvider<BuAnnouncementsSnap>(key: BuWidgetTokens.keyAcademic,
                                                      sampleJSON: BuSampleData.academic,
                                                      extraDates: BuTimeline.noExtra)
        ) { entry in
            BuAnnouncementsView(entry: entry, icon: "calendar")
        }
        .configurationDisplayName("widget.academic.name")
        .description("widget.academic.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct BUAnnouncementsWidget: Widget {
    let kind: String = "BUAnnouncementsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BuProvider<BuAnnouncementsSnap>(key: BuWidgetTokens.keyAnnouncements,
                                                      sampleJSON: BuSampleData.announcements,
                                                      extraDates: BuTimeline.noExtra)
        ) { entry in
            BuAnnouncementsView(entry: entry)
        }
        .configurationDisplayName("widget.announcements.name")
        .description("widget.announcements.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

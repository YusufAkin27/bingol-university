// BuQuickAccessWidget.swift
// Hizli Erisim (kind BUQuickAccessWidget). Widget govdesi/baslik: bukampus://home; HER KARO kendi baglantisini acar.
// Small: baslik/logo YOK, ic bosluk 12, 2x2 (smallIds); medium/large: 4x2 (8 karo). Bos durum yok.
// Tasarim: design/widget-previews/quickaccess/README.md

import SwiftUI
import WidgetKit

struct BuQuickAccessView: View {
    let entry: BuEntry<BuQuickSnap>
    @Environment(\.widgetFamily) private var family

    var body: some View {
        BuFrame(ctx: entry.ctx, link: buLink(entry.state),
                padding: family.isSmall ? BuWidgetTokens.paddingQuickSmall : BuWidgetTokens.paddingDefault) { theme in
            content(theme)
        }
    }

    @ViewBuilder
    private func content(_ t: BuTheme) -> some View {
        switch entry.state {
        case .signedOut:
            BuSignedOutView(ctx: entry.ctx, theme: t)
        case .empty(let snap), .data(let snap):
            let items = snap.items ?? []
            if items.isEmpty {
                BuSignedOutView(ctx: entry.ctx, theme: t)
            } else {
                dataView(snap, items, t)
            }
        }
    }

    @ViewBuilder
    private func dataView(_ snap: BuQuickSnap, _ items: [BuQuickItem], _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        switch family {
        case .systemSmall:
            grid(smallItems(snap, items), columns: 2, iconSize: BuWidgetTokens.iconRowLarge,
                 radius: BuWidgetTokens.radiusChip, t)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "search", caption: snap.str("caption"), gap: BuWidgetTokens.s10)
                grid(Array(items.prefix(BuWidgetTokens.quickMediumTiles)), columns: 4,
                     iconSize: BuWidgetTokens.iconTileMedium, radius: BuWidgetTokens.radiusTile, t)
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, caption: snap.str("caption"), gap: BuWidgetTokens.s4)
                BuLabel(text: snap.str("heading"), role: BuWidgetTokens.title, color: t.text1, lang: lang)
                BuLabel(text: snap.str("sub"), role: BuWidgetTokens.small, color: t.text3, lang: lang)
                    .padding(.bottom, BuWidgetTokens.s14)
                grid(Array(items.prefix(BuWidgetTokens.quickLargeTiles)), columns: 4,
                     iconSize: BuWidgetTokens.iconTileLarge, radius: BuWidgetTokens.radiusTile, t)
            }
        }
    }

    /// smallIds sirasiyla 4 karo; yoksa ilk 4.
    private func smallItems(_ snap: BuQuickSnap, _ items: [BuQuickItem]) -> [BuQuickItem] {
        var out: [BuQuickItem] = []
        for id in snap.smallIds ?? [] {
            if let it = items.first(where: { $0.id == id }) { out.append(it) }
        }
        if out.isEmpty { out = Array(items.prefix(BuWidgetTokens.quickSmallTiles)) }
        return Array(out.prefix(BuWidgetTokens.quickSmallTiles))
    }

    private func grid(_ items: [BuQuickItem], columns: Int, iconSize: CGFloat, radius: CGFloat, _ t: BuTheme) -> some View {
        var rows: [[BuQuickItem]] = []
        var i = 0
        while i < items.count {
            rows.append(Array(items[i..<min(items.count, i + columns)]))
            i += columns
        }
        return VStack(spacing: BuWidgetTokens.tileGap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { r in
                HStack(spacing: BuWidgetTokens.tileGap) {
                    ForEach(Array(r.element.enumerated()), id: \.offset) { c in
                        tile(c.element, iconSize: iconSize, radius: radius, t)
                    }
                    // Eksik karo: izgara hizasini koru.
                    if r.element.count < columns {
                        ForEach(0..<(columns - r.element.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tile(_ item: BuQuickItem, iconSize: CGFloat, radius: CGFloat, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let spacing = iconSize >= BuWidgetTokens.iconRowLarge ? BuWidgetTokens.s6 : BuWidgetTokens.s4
        return BuLinkRow(item.deepLink) {
            VStack(spacing: spacing) {
                BuIcon(name: item.icon ?? "", size: iconSize, color: t.text1)
                BuLabel(text: item.label ?? "", role: BuWidgetTokens.micro, color: t.text2, lang: lang, align: .center)
            }
            .padding(.horizontal, BuWidgetTokens.s2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(t.chip))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(item.a11yLabel ?? item.label ?? ""))
        }
    }
}

struct BUQuickAccessWidget: Widget {
    let kind: String = "BUQuickAccessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BuProvider<BuQuickSnap>(key: BuWidgetTokens.keyQuickAccess, sampleJSON: BuSampleData.quickaccess,
                                              extraDates: BuTimeline.noExtra)
        ) { entry in
            BuQuickAccessView(entry: entry)
        }
        .configurationDisplayName("widget.quickaccess.name")
        .description("widget.quickaccess.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

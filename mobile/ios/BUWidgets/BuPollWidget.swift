// BuPollWidget.swift
// Gunun Anketi (kind BUPollWidget). Dokununca bukampus://poll/{id} (anket yoksa bukampus://home). YALNIZ gosterim:
// oy verme uygulamada (interaktif widget YOK). Gizli oy: kimlik hicbir yerde yok.
// Yuzde/cubuk yalniz userVoted && resultsVisible iken cizilir. Tasarim: design/widget-previews/poll/README.md

import SwiftUI
import WidgetKit

private struct BuPollBar: View {
    let fraction: Double
    let fill: Color
    let track: Color
    let fillOpacity: Double

    var body: some View {
        let f = max(0, min(1, fraction))
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: BuWidgetTokens.radiusBar, style: .continuous).fill(track)
            GeometryReader { g in
                RoundedRectangle(cornerRadius: BuWidgetTokens.radiusBar, style: .continuous)
                    .fill(fill.opacity(fillOpacity))
                    .frame(width: g.size.width * CGFloat(f))
            }
        }
        .frame(height: BuWidgetTokens.barHeight)
    }
}

struct BuPollView: View {
    let entry: BuEntry<BuPollSnap>
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
            if let q = snap.question, !q.isEmpty, (snap.options ?? []).count >= 2 || family.isSmall {
                dataView(snap, q, t)
                    .buA11y(snap.a11y)
            } else {
                emptyView(snap, t)
            }
        }
    }

    // MARK: Bos durum

    @ViewBuilder
    private func emptyView(_ snap: BuPollSnap, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        if family.isSmall {
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "vote", caption: snap.str("caption"))
                BuEmptyLeading(theme: t, lang: lang, title: snap.str("emptyTitle"), titleLines: 2,
                               sub: snap.str("emptySmallSub"), subRole: BuWidgetTokens.small, subColor: t.text3)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "vote", caption: snap.str("captionFull"))
                BuEmptyLeading(theme: t, lang: lang, title: snap.str("emptyTitle"), titleLines: 1,
                               sub: snap.str("emptySub"), subRole: BuWidgetTokens.body, subColor: t.text2)
            }
        }
    }

    // MARK: Veri

    /// Cubuk/yuzde cizilebilir mi (oy verilmis + sonuclar gorunur + tum yuzdeler dolu).
    private func showsResults(_ snap: BuPollSnap) -> Bool {
        guard snap.userVoted == true, snap.resultsVisible == true else { return false }
        let opts = snap.options ?? []
        return !opts.isEmpty && opts.allSatisfy { $0.percent != nil }
    }

    @ViewBuilder
    private func dataView(_ snap: BuPollSnap, _ q: String, _ t: BuTheme) -> some View {
        switch family {
        case .systemSmall:
            smallView(snap, q, t)
        case .systemMedium:
            mediumView(snap, q, t)
        default:
            largeView(snap, q, t)
        }
    }

    private func pill(_ snap: BuPollSnap, _ t: BuTheme) -> some View {
        return BuLabel(text: snap.str("vote"), role: BuWidgetTokens.body, color: t.inverseFg, lang: entry.ctx.lang)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, BuWidgetTokens.pillPaddingX)
            .frame(height: BuWidgetTokens.pillHeight)
            .background(Capsule().fill(t.inverseBg))
    }

    private func smallView(_ snap: BuPollSnap, _ q: String, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "vote", caption: snap.str("caption"))
            BuLabel(text: q, role: BuWidgetTokens.question, color: t.text1,
                    lines: BuWidgetTokens.pollSmallQuestionLines, lang: lang)
            Spacer(minLength: 0)
            if snap.userVoted == true {
                BuLabel(text: snap.str("voted"), role: BuWidgetTokens.body, color: t.text2, lang: lang)
            } else {
                pill(snap, t)
            }
        }
    }

    private func isLeader(_ snap: BuPollSnap, _ i: Int) -> Bool {
        guard let l = snap.leaderIndex else { return true }   // null: hepsi esit agirlikta
        return l == i
    }

    private func mediumOption(_ snap: BuPollSnap, _ i: Int, _ o: BuPollOption, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let leader = isLeader(snap, i)
        return VStack(alignment: .leading, spacing: BuWidgetTokens.s4) {
            HStack(spacing: BuWidgetTokens.s8) {
                BuLabel(text: o.label ?? "", role: BuWidgetTokens.small, color: t.text1, lang: lang)
                    .frame(maxWidth: .infinity, alignment: .leading)
                BuLabel(text: o.percentText ?? "", role: BuWidgetTokens.small, color: leader ? t.text1 : t.text2, lang: lang)
                    .fixedSize(horizontal: true, vertical: false)
            }
            BuPollBar(fraction: Double(o.percent ?? 0) / 100, fill: t.barFill, track: t.barTrack,
                      fillOpacity: leader ? 1 : BuWidgetTokens.opacityNonLeaderBar)
        }
    }

    private func mediumView(_ snap: BuPollSnap, _ q: String, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let opts = Array((snap.options ?? []).prefix(BuWidgetTokens.pollMediumOptions))
        let results = showsResults(snap)
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "vote", caption: snap.str("captionFull"), gap: BuWidgetTokens.s8)
            GeometryReader { g in
                HStack(alignment: .top, spacing: BuWidgetTokens.s16) {
                    VStack(alignment: .leading, spacing: 0) {
                        BuLabel(text: q, role: BuWidgetTokens.question, color: t.text1,
                                lines: BuWidgetTokens.pollMediumQuestionLines, lang: lang)
                        Spacer(minLength: 0)
                        if let micro = snap.microLine, !micro.isEmpty {
                            BuLabel(text: micro, role: BuWidgetTokens.micro, color: t.text3, lang: lang)
                        }
                    }
                    .frame(width: max(0, (g.size.width - BuWidgetTokens.s16) * 0.4), height: g.size.height,
                           alignment: .topLeading)
                    if results {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(opts.enumerated()), id: \.offset) { pair in
                                if pair.offset > 0 { Spacer(minLength: BuWidgetTokens.s4) }
                                mediumOption(snap, pair.offset, pair.element, t)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        VStack(alignment: .leading, spacing: BuWidgetTokens.s6) {
                            ForEach(Array(opts.enumerated()), id: \.offset) { pair in
                                BuLabel(text: pair.element.label ?? "", role: BuWidgetTokens.small, color: t.text1, lang: lang)
                            }
                            Spacer(minLength: 0)
                            if snap.userVoted == true {
                                BuLabel(text: snap.str("voted"), role: BuWidgetTokens.body, color: t.text2, lang: lang)
                            } else {
                                pill(snap, t)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func largeOption(_ snap: BuPollSnap, _ i: Int, _ o: BuPollOption, results: Bool, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let leader = isLeader(snap, i)
        return VStack(alignment: .leading, spacing: BuWidgetTokens.s6) {
            HStack(spacing: BuWidgetTokens.s8) {
                BuLabel(text: o.label ?? "", role: BuWidgetTokens.body, color: t.text1, lang: lang)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if results {
                    BuLabel(text: o.percentText ?? "", role: BuWidgetTokens.body, color: leader ? t.text1 : t.text2, lang: lang)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            if results {
                BuPollBar(fraction: Double(o.percent ?? 0) / 100, fill: t.barFill, track: t.barTrack,
                          fillOpacity: leader ? 1 : BuWidgetTokens.opacityNonLeaderBar)
            }
        }
    }

    private func largeView(_ snap: BuPollSnap, _ q: String, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let opts = Array((snap.options ?? []).prefix(BuWidgetTokens.pollLargeOptionsMax))
        let results = showsResults(snap)
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "vote", caption: snap.str("captionFull"))
            BuLabel(text: q, role: BuWidgetTokens.title, color: t.text1,
                    lines: BuWidgetTokens.pollLargeQuestionLines, lang: lang)
                .padding(.bottom, BuWidgetTokens.s16)
            VStack(alignment: .leading, spacing: BuWidgetTokens.s14) {
                ForEach(Array(opts.enumerated()), id: \.offset) { pair in
                    largeOption(snap, pair.offset, pair.element, results: results, t)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: BuWidgetTokens.s4) {
                if let secret = snap.secretLine, !secret.isEmpty {
                    BuIcon(name: "lock", size: BuWidgetTokens.iconMeta, color: t.text2)
                    BuLabel(text: secret, role: BuWidgetTokens.small, color: t.text2, lang: lang)
                }
                Spacer(minLength: BuWidgetTokens.s4)
                BuLabel(text: snap.str("detail"), role: BuWidgetTokens.small, color: t.text1, lang: lang)
                    .fixedSize(horizontal: true, vertical: false)
                BuIcon(name: "chevron-right", size: BuWidgetTokens.iconMeta, color: t.text1, mirrorsInRTL: true)
            }
        }
    }
}

struct BUPollWidget: Widget {
    let kind: String = "BUPollWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BuProvider<BuPollSnap>(key: BuWidgetTokens.keyPoll, sampleJSON: BuSampleData.poll,
                                             extraDates: BuTimeline.noExtra)
        ) { entry in
            BuPollView(entry: entry)
        }
        .configurationDisplayName("widget.poll.name")
        .description("widget.poll.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

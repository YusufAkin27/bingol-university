// BuSocialWidget.swift
// Sosyal Bildirim Ozeti (kind BUSocialWidget). YALNIZ SAYILAR (KVKK): kisi adi, mesaj metni, foto, avatar yok.
// Small: tum widget snapshot.deepLink (chat ya da sifir olmayan ilk hedef); medium sutun / large satir basina ayri hedef:
// mesaj -> chat, bildirim -> notifications, begeni/takipci -> discover. Tasarim: design/widget-previews/social/README.md

import SwiftUI
import WidgetKit

struct BuSocialView: View {
    let entry: BuEntry<BuSocialSnap>
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
            if snap.allZero == true {
                emptyView(snap, t)
            } else {
                dataView(snap, t)
                    .buA11y(family.isSmall ? snap.a11y : nil)
            }
        }
    }

    // MARK: Bos durum (hepsi 0; kirmizi yok)

    @ViewBuilder
    private func emptyView(_ snap: BuSocialSnap, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "message-square", caption: snap.str("captionEmpty"))
                BuEmptyLeading(theme: t, lang: lang, icon: "circle-check", iconSize: BuWidgetTokens.iconEmptySmall,
                               title: snap.str("emptyTitle"), titleLines: 2, subColor: t.text2)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "message-circle", caption: snap.str("captionFull"))
                BuEmptyLeading(theme: t, lang: lang, icon: "circle-check", iconSize: BuWidgetTokens.iconEmptyMedium,
                               title: snap.str("emptyTitle"), titleLines: 1,
                               sub: snap.str("emptySub"), subRole: BuWidgetTokens.body, subColor: t.text2)
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                BuHeader(theme: t, lang: lang, icon: "message-circle", caption: snap.str("captionFull"))
                BuEmptyLeading(theme: t, lang: lang, icon: "circle-check", iconSize: BuWidgetTokens.iconEmptyLarge,
                               title: snap.str("emptyTitle"), titleLines: 1,
                               sub: snap.str("emptySub"), subRole: BuWidgetTokens.body, subColor: t.text2)
            }
        }
    }

    // MARK: Veri

    private func text(_ txt: String?, _ n: Int?) -> String {
        if let s = txt, !s.isEmpty { return s }
        return String(n ?? 0)
    }

    @ViewBuilder
    private func dataView(_ snap: BuSocialSnap, _ t: BuTheme) -> some View {
        switch family {
        case .systemSmall:
            smallView(snap, t)
        case .systemMedium:
            mediumView(snap, t)
        default:
            largeView(snap, t)
        }
    }

    private func smallView(_ snap: BuSocialSnap, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "message-square", caption: snap.str("captionSmall"))
            BuLabel(text: text(snap.unreadMessagesText, snap.unreadMessages), role: BuWidgetTokens.number,
                    color: t.text1, lang: lang)
            BuLabel(text: snap.str("unreadSmall"), role: BuWidgetTokens.small, color: t.text2, lang: lang)
            Spacer(minLength: 0)
            HStack(spacing: BuWidgetTokens.s12) {
                HStack(spacing: BuWidgetTokens.s4) {
                    BuIcon(name: "bell", size: BuWidgetTokens.iconHeader, color: t.text2)
                    BuLabel(text: text(snap.newNotificationsText, snap.newNotifications),
                            role: BuWidgetTokens.small, color: t.text2, lang: lang)
                }
                HStack(spacing: BuWidgetTokens.s4) {
                    BuIcon(name: "heart", size: BuWidgetTokens.iconHeader, color: t.heart)
                    BuLabel(text: text(snap.newLikesAndFollowersText, snap.newLikesAndFollowers),
                            role: BuWidgetTokens.small, color: t.text2, lang: lang)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private struct Stat {
        let icon: String
        let iconColor: Color
        let number: String
        let label: String
        let row: String
        let sub: String
        let link: String?
    }

    private func stats(_ snap: BuSocialSnap, _ t: BuTheme) -> [Stat] {
        return [
            Stat(icon: "message-circle", iconColor: t.text2,
                 number: text(snap.unreadMessagesText, snap.unreadMessages),
                 label: snap.str("labelMessages"), row: snap.str("rowMessages"), sub: snap.str("subMessages"),
                 link: snap.links?.messages),
            Stat(icon: "bell", iconColor: t.text2,
                 number: text(snap.newNotificationsText, snap.newNotifications),
                 label: snap.str("labelNotifications"), row: snap.str("rowNotifications"), sub: snap.str("subNotifications"),
                 link: snap.links?.notifications),
            Stat(icon: "heart", iconColor: t.heart,
                 number: text(snap.newLikesAndFollowersText, snap.newLikesAndFollowers),
                 label: snap.str("labelLikes"), row: snap.str("rowLikes"), sub: snap.str("subLikes"),
                 link: snap.links?.likes),
        ]
    }

    private func mediumView(_ snap: BuSocialSnap, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let list = stats(snap, t)
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "message-circle", caption: snap.str("captionFull"))
            HStack(spacing: BuWidgetTokens.s12) {
                ForEach(Array(list.enumerated()), id: \.offset) { pair in
                    if pair.offset > 0 { BuVDivider(theme: t) }
                    BuLinkRow(pair.element.link) {
                        VStack(spacing: BuWidgetTokens.s6) {
                            BuIcon(name: pair.element.icon, size: BuWidgetTokens.iconSocialMedium,
                                   color: pair.element.iconColor)
                            BuLabel(text: pair.element.number, role: BuWidgetTokens.number, color: t.text1,
                                    lang: lang, align: .center)
                            BuLabel(text: pair.element.label, role: BuWidgetTokens.small, color: t.text2,
                                    lang: lang, align: .center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(pair.element.label + " " + pair.element.number))
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func largeView(_ snap: BuSocialSnap, _ t: BuTheme) -> some View {
        let lang = entry.ctx.lang
        let list = stats(snap, t)
        return VStack(alignment: .leading, spacing: 0) {
            BuHeader(theme: t, lang: lang, icon: "message-circle", caption: snap.str("captionFull"),
                     gap: BuWidgetTokens.s4)
            BuLabel(text: snap.str("heading"), role: BuWidgetTokens.title, color: t.text1, lang: lang)
            BuLabel(text: snap.str("privacyNote"), role: BuWidgetTokens.small, color: t.text3, lang: lang)
                .padding(.bottom, BuWidgetTokens.s14)
            VStack(spacing: BuWidgetTokens.tileGap) {
                ForEach(Array(list.enumerated()), id: \.offset) { pair in
                    BuLinkRow(pair.element.link) {
                        HStack(spacing: BuWidgetTokens.s12) {
                            BuIcon(name: pair.element.icon, size: BuWidgetTokens.iconRowLarge,
                                   color: pair.element.iconColor)
                            VStack(alignment: .leading, spacing: 0) {
                                BuLabel(text: pair.element.row, role: BuWidgetTokens.body, color: t.text1, lang: lang)
                                BuLabel(text: pair.element.sub, role: BuWidgetTokens.micro, color: t.text3, lang: lang)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            BuLabel(text: pair.element.number, role: BuWidgetTokens.numberRow, color: t.text1, lang: lang)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, BuWidgetTokens.s14)
                        .frame(height: BuWidgetTokens.rowSocialLarge)
                        .background(RoundedRectangle(cornerRadius: BuWidgetTokens.radiusTile, style: .continuous).fill(t.chip))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(pair.element.row + " " + pair.element.number))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct BUSocialWidget: Widget {
    let kind: String = "BUSocialWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: BuProvider<BuSocialSnap>(key: BuWidgetTokens.keySocial, sampleJSON: BuSampleData.social,
                                               extraDates: BuTimeline.noExtra)
        ) { entry in
            BuSocialView(entry: entry)
        }
        .configurationDisplayName("widget.social.name")
        .description("widget.social.desc")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

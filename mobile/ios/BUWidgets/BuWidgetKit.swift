// BuWidgetKit.swift
// Ortak arayuz parcalari: tema, yazi, baslik satiri, logo, kabuk (arka plan + kenarlik + ic bosluk + RTL),
// oturumsuz ve bos durum, baglanti yardimcilari. Olculer BuWidgetTokens'tan (ham sayi yok).

import SwiftUI
import WidgetKit

// MARK: - Tema (sistem acik/koyu)

struct BuTheme {
    let bg: Color
    let chip: Color
    let border: Color
    let text1: Color
    let text2: Color
    let text3: Color
    let inverseBg: Color
    let inverseFg: Color
    let barFill: Color
    let barTrack: Color
    let badgeFill: Color
    let badgeBorder: Color
    let dotPassive: Color
    let heart: Color
    let danger: Color

    init(_ scheme: ColorScheme) {
        let p = BuWidgetPalette.palette(for: scheme)
        func c(_ v: UInt32) -> Color { return BuWidgetPalette.color(v) }
        bg = c(p.bg); chip = c(p.chip); border = c(p.border)
        text1 = c(p.text1); text2 = c(p.text2); text3 = c(p.text3)
        inverseBg = c(p.inverseBg); inverseFg = c(p.inverseFg)
        barFill = c(p.barFill); barTrack = c(p.barTrack)
        badgeFill = c(p.badgeFill); badgeBorder = c(p.badgeBorder); dotPassive = c(p.dotPassive)
        heart = c(p.heart); danger = c(p.danger)
    }
}

// MARK: - Yazi

/// Tek renkli, tek agirlikli (400) metin. `lines` = en cok satir (kuyruk `...`); tek satirda yukseklik
/// satir yuksekligine sabitlenir (tasarim satir ritmi). Arapcada BUYUK HARF uygulanmaz.
struct BuLabel: View {
    let text: String
    let role: BuWidgetTokens.TextRole
    let color: Color
    var lines: Int = 1
    var lang: String = "tr"
    var align: TextAlignment = .leading

    private var shown: String {
        if role.caps && lang != "ar" {
            return text.uppercased(with: Locale(identifier: lang))
        }
        return text
    }

    var body: some View {
        let t = Text(shown)
            .font(.system(size: role.size, weight: BuWidgetTokens.fontWeight))
            .kerning(lang == "ar" ? 0 : role.trackingPoints)   // Arapca: harf araligi baglantiyi bozar
            .foregroundColor(color)
            .lineLimit(lines)
            .truncationMode(.tail)
            .multilineTextAlignment(align)
            .fixedSize(horizontal: false, vertical: lines > 1)
        if lines == 1 {
            return AnyView(t.frame(height: role.line, alignment: .leading))
        }
        return AnyView(t.lineSpacing(role.lineSpacing))
    }
}

// MARK: - Logo

struct BuLogo: View {
    var height: CGFloat = BuWidgetTokens.logoHeight

    var body: some View {
        Image("BuLogo")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
            .opacity(BuWidgetTokens.logoOpacity)
            .accessibilityHidden(true)
    }
}

// MARK: - Baslik satiri (ikon + caption solda, logo sagda)

struct BuHeader: View {
    let theme: BuTheme
    let lang: String
    var icon: String? = nil
    let caption: String
    var showLogo: Bool = true
    var gap: CGFloat = BuWidgetTokens.headerGap

    var body: some View {
        HStack(spacing: BuWidgetTokens.s4) {
            if let icon = icon {
                BuIcon(name: icon, size: BuWidgetTokens.iconHeader, color: theme.text3)
            }
            BuLabel(text: caption, role: BuWidgetTokens.caption, color: theme.text3, lang: lang)
            Spacer(minLength: BuWidgetTokens.s4)
            if showLogo { BuLogo() }
        }
        .frame(height: BuWidgetTokens.headerHeight)
        .padding(.bottom, gap)
    }
}

/// Etkinlik / duyuru basligi: logo (14) + metin (micro, text2) solda.
struct BuLogoTitleHeader: View {
    let theme: BuTheme
    let lang: String
    let title: String
    var trailing: String? = nil
    var gap: CGFloat = BuWidgetTokens.s10

    var body: some View {
        HStack(spacing: BuWidgetTokens.s6) {
            BuLogo(height: BuWidgetTokens.logoHeightEvents)
            BuLabel(text: title, role: BuWidgetTokens.micro, color: theme.text2, lang: lang)
            Spacer(minLength: BuWidgetTokens.s4)
            if let t = trailing {
                BuLabel(text: t, role: BuWidgetTokens.micro, color: theme.text3, lang: lang)
            }
        }
        .frame(height: BuWidgetTokens.headerHeight)
        .padding(.bottom, gap)
    }
}

/// Ince ayirici (1 px, border rengi).
struct BuDivider: View {
    let theme: BuTheme
    var body: some View {
        Rectangle().fill(theme.border).frame(height: BuWidgetTokens.borderWidth)
    }
}

struct BuVDivider: View {
    let theme: BuTheme
    var body: some View {
        Rectangle().fill(theme.border).frame(width: BuWidgetTokens.borderWidth)
    }
}

// MARK: - Baglantilar

enum BuLink {
    /// Yalniz bukampus:// semasi kabul edilir; digerleri nil (dokununca hicbir sey acilmaz).
    static func url(_ s: String?) -> URL? {
        guard let s = s, s.hasPrefix(BuWidgetTokens.urlScheme + "://"), let u = URL(string: s) else { return nil }
        return u
    }
    static let home = URL(string: "bukampus://home")
}

/// Satir bazli dokunma: baglanti gecerliyse `Link`, degilse duz icerik (widgetURL'e dusulur).
struct BuLinkRow<Content: View>: View {
    let link: String?
    let content: Content

    init(_ link: String?, @ViewBuilder content: () -> Content) {
        self.link = link
        self.content = content()
    }

    var body: some View {
        if let u = BuLink.url(link) {
            Link(destination: u) { content }
        } else {
            content
        }
    }
}

// MARK: - Kabuk

/// iOS 17+: sistem icerik kenar boslugu (varsayilan ~16) `widgetContentMargins` ile okunup hedef ic bosluga
/// (16 / hizli erisim small 12) tamamlanir; boylece iOS 15-17 ayni olcude cizer.
@available(iOS 17.0, *)
private struct BuInset17: ViewModifier {
    let target: CGFloat
    @Environment(\.widgetContentMargins) private var margins

    func body(content: Content) -> some View {
        content.padding(EdgeInsets(top: max(0, target - margins.top),
                                   leading: max(0, target - margins.leading),
                                   bottom: max(0, target - margins.bottom),
                                   trailing: max(0, target - margins.trailing)))
    }
}

private struct BuInset: ViewModifier {
    let target: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.modifier(BuInset17(target: target))
        } else {
            content.padding(target)
        }
    }
}

/// Tek duz zemin + 1 px kenarlik (ContainerRelativeShape: sistem kose yaricapina otomatik uyar).
struct BuBackground: View {
    let theme: BuTheme

    var body: some View {
        ZStack {
            ContainerRelativeShape().fill(theme.bg)
            ContainerRelativeShape().strokeBorder(theme.border, lineWidth: BuWidgetTokens.borderWidth)
        }
    }
}

extension View {
    @ViewBuilder
    func buContainerBackground(_ theme: BuTheme) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) { BuBackground(theme: theme) }
        } else {
            self.background(BuBackground(theme: theme))
        }
    }
}

/// Her widget'in kokunda: tema + yon (RTL) + sabit yazi olcegi + ic bosluk + arka plan + widgetURL.
struct BuFrame<Content: View>: View {
    let ctx: BuContext
    var link: URL? = nil
    var padding: CGFloat = BuWidgetTokens.paddingDefault
    let content: (BuTheme) -> Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let theme = BuTheme(scheme)
        return content(theme)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .modifier(BuInset(target: padding))
            .environment(\.layoutDirection, ctx.rtl ? .rightToLeft : .leftToRight)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .widgetURL(link)
            .buContainerBackground(theme)
    }
}

// MARK: - Oturumsuz ve bos durum

/// Oturumsuz: display "Giris yap" + micro alt metin; dokununca bukampus://home.
struct BuSignedOutView: View {
    let ctx: BuContext
    let theme: BuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: BuWidgetTokens.s4) {
            Spacer(minLength: 0)
            BuLabel(text: ctx.signedOutTitle, role: BuWidgetTokens.display, color: theme.text1, lines: 2, lang: ctx.lang)
            BuLabel(text: ctx.signedOutSub, role: BuWidgetTokens.micro, color: theme.text2, lines: 2, lang: ctx.lang)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Bos durum: soldan hizali, dikey ortali display baslik + alt metin (menu, ders, anket, sosyal).
struct BuEmptyLeading: View {
    let theme: BuTheme
    let lang: String
    var icon: String? = nil
    var iconSize: CGFloat = BuWidgetTokens.iconEmptySmall
    let title: String
    var titleLines: Int = 2
    var sub: String? = nil
    var subRole: BuWidgetTokens.TextRole = BuWidgetTokens.small
    var subColor: Color
    var subLines: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: BuWidgetTokens.s4) {
            Spacer(minLength: 0)
            if let icon = icon {
                BuIcon(name: icon, size: iconSize, color: theme.text3)
                    .padding(.bottom, BuWidgetTokens.s4)
            }
            BuLabel(text: title, role: BuWidgetTokens.display, color: theme.text1, lines: titleLines, lang: lang)
            if let sub = sub, !sub.isEmpty {
                BuLabel(text: sub, role: subRole, color: subColor, lines: subLines, lang: lang)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Bos durum: yatay ortali ikon + baslik + alt metin (etkinlik, duyuru).
struct BuEmptyCentered: View {
    let theme: BuTheme
    let lang: String
    let icon: String
    let iconSize: CGFloat
    let title: String
    var titleRole: BuWidgetTokens.TextRole = BuWidgetTokens.body
    var sub: String? = nil
    var subRole: BuWidgetTokens.TextRole = BuWidgetTokens.micro
    var subLines: Int = 1

    var body: some View {
        VStack(spacing: BuWidgetTokens.s8) {
            Spacer(minLength: 0)
            BuIcon(name: icon, size: iconSize, color: theme.text3)
            BuLabel(text: title, role: titleRole, color: theme.text2, lines: 2, lang: lang, align: .center)
            if let sub = sub, !sub.isEmpty {
                BuLabel(text: sub, role: subRole, color: theme.text3, lines: subLines, lang: lang, align: .center)
                    .frame(maxWidth: 220)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Boyut yardimcisi

enum BuFit {
    /// n = min(tavan, floor((H + aralik) / (satir + aralik))); en az 1.
    static func rows(available: CGFloat, row: CGFloat, gap: CGFloat, cap: Int) -> Int {
        let n = Int(floor((available + gap) / (row + gap)))
        return max(1, min(cap, n))
    }
}

extension WidgetFamily {
    var isSmall: Bool { return self == .systemSmall }
    var isMedium: Bool { return self == .systemMedium }
}

// MARK: - Genel dokunma hedefi ve erisilebilirlik

/// Widget govdesi baglantisi: veri/bos durumda snapshot.deepLink, oturumsuzda bukampus://home.
func buLink<S: BuSnapshot>(_ state: BuState<S>) -> URL? {
    switch state {
    case .signedOut:
        return BuLink.home
    case .data(let s), .empty(let s):
        return BuLink.url(s.deepLink) ?? BuLink.home
    }
}

extension View {
    /// Ekran okuyucu: widget TEK oge, hazir ozet cumle (snapshot.a11y). Satir baglantisi olmayan widget'larda kullanilir.
    @ViewBuilder
    func buA11y(_ summary: String?) -> some View {
        if let s = summary, !s.isEmpty {
            self.accessibilityElement(children: .ignore).accessibilityLabel(Text(s))
        } else {
            self
        }
    }
}

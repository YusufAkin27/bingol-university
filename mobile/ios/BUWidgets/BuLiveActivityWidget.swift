// BuLiveActivityWidget.swift
// Canli Etkinlik arayuzu: kilit ekrani + Dynamic Island (compact / expanded / minimal).
// Tasarim: monochrome, yazi agirligi her yerde .regular (kalin yok), kirmizi vurgu YALNIZ "canli" noktasinda.
// UYARI: Windows'ta derlenemedi; macOS/Codemagic'te dogrulayin.

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct BuLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BuLiveActivityAttributes.self) { context in
            BuLiveLockView(context: context)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BuLiveIcon(kind: context.attributes.kind, size: 18)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    BuLiveTimer(state: context.state)
                        .font(.system(size: 20, weight: .regular))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.system(size: 15, weight: .regular))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(BuLiveText.subtitle(context.state))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                BuLiveIcon(kind: context.attributes.kind, size: 12)
            } compactTrailing: {
                BuLiveTimer(state: context.state)
                    .font(.system(size: 12, weight: .regular))
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                BuLiveIcon(kind: context.attributes.kind, size: 12)
            }
            .widgetURL(BuLiveLink.url(context.attributes))
        }
    }
}

@available(iOS 16.1, *)
enum BuLiveLink {
    /// Mevcut ana ekran widget'larinin derin baglanti semasi: bukampus://<hedef>
    static func url(_ a: BuLiveActivityAttributes) -> URL? {
        let host = a.kind == "EXAM" ? "timetable" : "events/\(a.refId)"
        return URL(string: "bukampus://\(host)")
    }
}

@available(iOS 16.1, *)
enum BuLiveText {
    static func subtitle(_ s: BuLiveActivityAttributes.ContentState) -> String {
        s.detail.isEmpty ? s.label : s.label + " - " + s.detail
    }
}

@available(iOS 16.1, *)
struct BuLiveIcon: View {
    let kind: String
    let size: CGFloat
    var body: some View {
        // Lucide cizgi ikonu (SF Symbols DEGIL): BuIcons.swift.
        BuIcon(name: kind == "EXAM" ? "calendar-clock" : "calendar", size: size, color: .primary)
            .frame(width: size, height: size)
    }
}

@available(iOS 16.1, *)
struct BuLiveTimer: View {
    let state: BuLiveActivityAttributes.ContentState
    var body: some View {
        if state.phase == "ended" || state.target <= Date() {
            Text("--:--")
        } else {
            Text(timerInterval: Date()...state.target, countsDown: true)
        }
    }
}

@available(iOS 16.1, *)
struct BuLiveLockView: View {
    let context: ActivityViewContext<BuLiveActivityAttributes>
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            BuLiveIcon(kind: context.attributes.kind, size: 22)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.title)
                    .font(.system(size: 15, weight: .regular))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if context.state.phase == "live" {
                        Circle()
                            .fill(Color(red: 247.0 / 255, green: 58.0 / 255, blue: 46.0 / 255))
                            .frame(width: 6, height: 6)
                    }
                    Text(BuLiveText.subtitle(context.state))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            BuLiveTimer(state: context.state)
                .font(.system(size: 24, weight: .regular))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110, alignment: .trailing)
        }
        .padding(16)
    }
}

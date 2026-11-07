// BUWidgetsBundle.swift
// Widget Extension girisi: yedi ana ekran widget'i (kind adlari DATA_CONTRACT bolum 10).
// Lock Screen widget'i ve interaktif widget KAPSAM DISI.

import SwiftUI
import WidgetKit

@main
struct BUWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BUMenuWidget()
        BUTimetableWidget()
        BUEventsWidget()
        BUAnnouncementsWidget()
        BUPollWidget()
        BUQuickAccessWidget()
        BUSocialWidget()
        // Canli Etkinlik (kilit ekrani + Dynamic Island), yalniz iOS 16.1+.
        if #available(iOS 16.1, *) {
            BuLiveActivityWidget()
        }
    }
}

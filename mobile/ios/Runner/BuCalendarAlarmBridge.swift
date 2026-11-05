import EventKit
import Flutter
import UIKit
import UserNotifications

/// iOS köprüleri: cihaz takvimine yazma (EventKit, kanal `bu_kampus/calendar`) ve alarm yedeği (kanal
/// `bu_kampus/alarm`). Dart tarafı: lib/core/platform/device_calendar.dart, device_alarm.dart.
///
/// UYARI: Bu dosya Windows'ta derlenemedi (macOS/Xcode gerekir); ilk macOS derlemesinde doğrulayın
/// (docs/IOS_RELEASE.md bölüm 9). `BuNativeBridge.register` iki köprüyü de kaydeder.

// MARK: - Takvim (EventKit)

/// Tam erişim (okuma + yazma) istenir: yalnız-yazma erişimi (`NSCalendarsWriteOnlyAccessUsageDescription`)
/// olay kimliğiyle GÜNCELLEMEYE ve SİLMEYE izin vermez; "ikinci ekleme mevcutları günceller, kaldır yalnız bizimkileri siler"
/// davranışı için tam erişim gerekir. Dokunulan tek şey Dart'ın verdiği kimlikli etkinliklerdir.
enum BuCalendarBridge {
  private static let store = EKEventStore()
  private static let istanbul = TimeZone(identifier: "Europe/Istanbul") ?? TimeZone.current
  private static let queue = DispatchQueue(label: "tr.com.bukampus.calendar", qos: .userInitiated)

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "bu_kampus/calendar", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in handle(call, result) }
  }

  private static func status() -> String {
    let s = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      switch s {
      case .fullAccess: return "granted"
      case .notDetermined: return "notDetermined"
      default: return "denied"  // writeOnly (yazma-yetmez), denied, restricted
      }
    }
    switch s {
    case .authorized: return "granted"
    case .notDetermined: return "notDetermined"
    default: return "denied"
    }
  }

  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "access":
      result(status())
    case "requestAccess":
      if status() != "notDetermined" {
        result(status())
        return
      }
      let done: (Bool, Error?) -> Void = { _, _ in DispatchQueue.main.async { result(status()) } }
      if #available(iOS 17.0, *) {
        store.requestFullAccessToEvents(completion: done)
      } else {
        store.requestAccess(to: .event, completion: done)
      }
    case "calendars":
      queue.async {
        let defaultId = store.defaultCalendarForNewEvents?.calendarIdentifier
        let list: [[String: Any]] = store.calendars(for: .event)
          .filter { $0.allowsContentModifications }
          .map {
            [
              "id": $0.calendarIdentifier,
              "name": $0.title,
              "account": $0.source?.title ?? "",
              "primary": $0.calendarIdentifier == defaultId,
              "local": $0.source?.sourceType == .local,
            ]
          }
        DispatchQueue.main.async { result(list) }
      }
    case "createCalendar":
      let name = (args["name"] as? String) ?? "BÜ Kampüs"
      queue.async {
        let id = createCalendar(name)
        DispatchQueue.main.async { result(id) }
      }
    case "upsertEvent":
      queue.async {
        let out = upsertEvent(args)
        DispatchQueue.main.async { result(out) }
      }
    case "deleteEvent":
      queue.async {
        let ok = deleteEvent(args)
        DispatchQueue.main.async { result(ok) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Aynı adlı yazılabilir takvim varsa onu kullanır; yoksa varsayılan takvimin kaynağında (yoksa yerel kaynakta) açar.
  private static func createCalendar(_ name: String) -> String? {
    if let existing = store.calendars(for: .event).first(where: { $0.title == name && $0.allowsContentModifications }) {
      return existing.calendarIdentifier
    }
    let source = store.defaultCalendarForNewEvents?.source
      ?? store.sources.first(where: { $0.sourceType == .local })
      ?? store.sources.first
    guard let src = source else { return nil }
    let cal = EKCalendar(for: .event, eventStore: store)
    cal.title = name
    cal.source = src
    cal.cgColor = UIColor(red: 0.863, green: 0.298, blue: 0.275, alpha: 1).cgColor
    do {
      try store.saveCalendar(cal, commit: true)
      return cal.calendarIdentifier
    } catch {
      return nil
    }
  }

  /// "2026-11-10" -> yerel saat diliminde o günün başlangıcı.
  private static func day(_ s: String?) -> Date? {
    guard let s = s else { return nil }
    let p = s.split(separator: "-").compactMap { Int($0) }
    guard p.count == 3 else { return nil }
    return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
  }

  private static func upsertEvent(_ a: [String: Any]) -> [String: Any]? {
    guard let calId = a["calendarId"] as? String,
          let cal = store.calendar(withIdentifier: calId),
          let title = a["title"] as? String else { return nil }
    let event: EKEvent
    var created = true
    if let eid = a["eventId"] as? String, let existing = store.event(withIdentifier: eid),
       existing.calendar.calendarIdentifier == calId {
      event = existing
      created = false
    } else {
      event = EKEvent(eventStore: store)
      event.calendar = cal
    }
    event.title = title
    event.notes = (a["notes"] as? String) ?? ""
    event.availability = .free
    if (a["allDay"] as? Bool) ?? true {
      guard let start = day(a["startDay"] as? String) else { return nil }
      let end = day(a["endDay"] as? String) ?? start
      event.isAllDay = true
      event.timeZone = nil
      event.startDate = start
      event.endDate = max(start, end)
      // Tek kaynak hatırlatıcı: o gün 08:00 (mutlak alarm; tüm gün etkinlikte de çalışır).
      if let min = (a["alarmDayMin"] as? NSNumber)?.intValue,
         let at = Calendar.current.date(byAdding: .minute, value: min, to: start) {
        event.alarms = [EKAlarm(absoluteDate: at)]
      } else {
        event.alarms = nil
      }
    } else {
      guard let s = (a["startMs"] as? NSNumber)?.doubleValue else { return nil }
      let e = (a["endMs"] as? NSNumber)?.doubleValue ?? (s + 3_600_000)
      event.isAllDay = false
      event.timeZone = istanbul
      event.startDate = Date(timeIntervalSince1970: s / 1000)
      event.endDate = Date(timeIntervalSince1970: e / 1000)
      if let at = (a["alarmAtMs"] as? NSNumber)?.doubleValue {
        event.alarms = [EKAlarm(absoluteDate: Date(timeIntervalSince1970: at / 1000))]
      } else {
        event.alarms = nil
      }
    }
    do {
      try store.save(event, span: .thisEvent, commit: true)
      guard let id = event.eventIdentifier else { return nil }
      return ["id": id, "created": created]
    } catch {
      return nil
    }
  }

  /// Yalnız verilen takvimdeki etkinliği siler; silindi ya da zaten yoksa true.
  private static func deleteEvent(_ a: [String: Any]) -> Bool {
    guard let calId = a["calendarId"] as? String, let eid = a["eventId"] as? String else { return false }
    guard let ev = store.event(withIdentifier: eid), ev.calendar.calendarIdentifier == calId else { return true }
    do {
      try store.remove(ev, span: .thisEvent, commit: true)
      return true
    } catch {
      return false
    }
  }
}

// MARK: - Alarm yedeği (yerel bildirim)

/// iOS'ta Saat uygulamasına alarm ekleyen genel bir API yoktur. Yedek: zamana duyarlı yerel bildirim
/// (`UNCalendarNotificationTrigger`): ders için haftalık tekrar, sınav için tarihli tek sefer. Kimlik öneki
/// `bu.alarm.` (`BuNativeBridge.cancelAll` çıkışta bunları da siler). Zamana duyarlı yetki için Runner.entitlements'ta
/// `com.apple.developer.usernotifications.time-sensitive` bulunmalıdır (yoksa bildirim normal düzeyde gelir).
enum BuAlarmBridge {
  private static let prefix = "bu.alarm."
  private static let istanbul = TimeZone(identifier: "Europe/Istanbul") ?? TimeZone.current

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "bu_kampus/alarm", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in handle(call, result) }
  }

  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isAvailable":
      result(true)  // bildirim yedeği her zaman vardır (izin ayrıca Dart'ta istenir)
    case "setAlarm":
      schedule(args, result)
    case "cancelFallback":
      removePending(matching: { $0.hasPrefix(prefix) }) { DispatchQueue.main.async { result(nil) } }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func removePending(matching: @escaping (String) -> Bool, completion: @escaping () -> Void) {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let ids = requests.map { $0.identifier }.filter(matching)
      if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
      completion()
    }
  }

  private static func schedule(_ a: [String: Any], _ result: @escaping FlutterResult) {
    guard let key = a["key"] as? String,
          let hour = (a["hour"] as? NSNumber)?.intValue,
          let minute = (a["minute"] as? NSNumber)?.intValue else {
      result(false)
      return
    }
    let content = UNMutableNotificationContent()
    let label = (a["label"] as? String) ?? ""
    let title = (a["title"] as? String) ?? ""
    content.title = title.isEmpty ? label : title
    content.body = (a["body"] as? String) ?? label
    content.sound = UNNotificationSound.default
    content.threadIdentifier = "alarm"
    if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
    var payload: [String: String] = [:]
    if let raw = a["payload"] as? [String: Any] {
      for (k, v) in raw { payload[k] = "\(v)" }
    }
    // BuNativeBridge yalnız `buLocal` işaretli bildirimlere yanıt verir (ön planda gösterme + dokunuş yönlendirme).
    content.userInfo = ["buLocal": true, "buPayload": payload]

    var requests: [UNNotificationRequest] = []
    let days = (a["days"] as? [NSNumber])?.map { $0.intValue } ?? []
    if !days.isEmpty {
      for d in days where (1...7).contains(d) {
        var dc = DateComponents()
        dc.timeZone = istanbul
        dc.weekday = d
        dc.hour = hour
        dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        requests.append(UNNotificationRequest(identifier: "\(prefix)\(key).\(d)", content: content, trigger: trigger))
      }
    } else {
      guard let date = a["date"] as? [String: Any],
            let y = (date["year"] as? NSNumber)?.intValue,
            let m = (date["month"] as? NSNumber)?.intValue,
            let dd = (date["day"] as? NSNumber)?.intValue else {
        result(false)
        return
      }
      var dc = DateComponents()
      dc.timeZone = istanbul
      dc.year = y
      dc.month = m
      dc.day = dd
      dc.hour = hour
      dc.minute = minute
      var cal = Calendar(identifier: .gregorian)
      cal.timeZone = istanbul
      guard let when = cal.date(from: dc), when > Date() else {
        result(false)  // geçmiş an: kurulmaz
        return
      }
      let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
      requests.append(UNNotificationRequest(identifier: "\(prefix)\(key)", content: content, trigger: trigger))
    }
    if requests.isEmpty {
      result(false)
      return
    }
    // Aynı anahtarlı eski kayıtlar silinir (yeniden kurma çift bildirim üretmez).
    removePending(matching: { $0 == "\(prefix)\(key)" || $0.hasPrefix("\(prefix)\(key).") }) {
      let center = UNUserNotificationCenter.current()
      let group = DispatchGroup()
      var failed = false
      for r in requests {
        group.enter()
        center.add(r) { error in
          if error != nil { failed = true }
          group.leave()
        }
      }
      group.notify(queue: .main) { result(!failed) }
    }
  }
}

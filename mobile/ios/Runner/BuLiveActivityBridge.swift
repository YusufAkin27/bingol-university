import ActivityKit
import Flutter
import Foundation

/// iOS Canli Etkinlik koprusu (kanal `bu_kampus/live_activity`). Dart tarafi: lib/core/live/live_activity_service.dart.
///
/// KAPSAM: yalniz kullanicinin kendi baslattigi etkinlik/sinav geri sayimi. Sohbet/arkadaslik/duyuru ASLA.
/// Yontemler: isSupported, start, update, end. Guncelleme jetonu (pushType .token) olustukca Dart'a `onToken` ile
/// iletilir; Dart sunucuya kaydeder (POST /api/live-activities). Jeton bildirim yukune KONMAZ.
///
/// UYARI: Bu dosya Windows'ta derlenemedi (macOS/Xcode gerekir); ilk macOS derlemesinde ve GERCEK CIHAZDA
/// dogrulayin (simulator Canli Etkinlik push jetonu uretmez). docs/IOS_RELEASE.md "Canli Etkinlikler".
/// iOS 16.2+ gerekir (ActivityContent API); daha eskide isSupported=false doner.
enum BuLiveActivityBridge {
  private static var channel: FlutterMethodChannel?

  static func register(messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: "bu_kampus/live_activity", binaryMessenger: messenger)
    channel = ch
    ch.setMethodCallHandler { call, result in handle(call, result) }
    if #available(iOS 16.2, *) { LiveImpl.reattach() }
  }

  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      if call.method == "isSupported" { result(false) } else { result(FlutterMethodNotImplemented) }
      return
    }
    LiveImpl.handle(call, result)
  }

  fileprivate static func sendToken(activityId: String, token: String) {
    DispatchQueue.main.async {
      channel?.invokeMethod("onToken", arguments: ["activityId": activityId, "token": token])
    }
  }

  fileprivate static func sendEnded(activityId: String) {
    DispatchQueue.main.async {
      channel?.invokeMethod("onEnded", arguments: ["activityId": activityId])
    }
  }
}

@available(iOS 16.2, *)
private enum LiveImpl {
  private static var observers: [String: Task<Void, Never>] = [:]

  static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isSupported":
      result(ActivityAuthorizationInfo().areActivitiesEnabled)
    case "list":
      result(Activity<BuLiveActivityAttributes>.activities.map {
        ["activityId": $0.id, "kind": $0.attributes.kind, "refId": NSNumber(value: $0.attributes.refId)]
      })
    case "start":
      start(args, result)
    case "update":
      guard let id = args["activityId"] as? String, let state = state(from: args),
            let activity = find(id) else { result(false); return }
      Task {
        await activity.update(ActivityContent(state: state, staleDate: staleDate(args)))
        result(true)
      }
    case "end":
      guard let id = args["activityId"] as? String, let activity = find(id) else { result(false); return }
      Task {
        await activity.end(nil, dismissalPolicy: .immediate)
        observers[id]?.cancel()
        observers[id] = nil
        result(true)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func find(_ id: String) -> Activity<BuLiveActivityAttributes>? {
    Activity<BuLiveActivityAttributes>.activities.first { $0.id == id }
  }

  private static func state(from args: [String: Any]) -> BuLiveActivityAttributes.ContentState? {
    guard let phase = args["phase"] as? String, let ms = (args["targetMs"] as? NSNumber)?.doubleValue else { return nil }
    return .init(phase: phase,
                 target: Date(timeIntervalSince1970: ms / 1000),
                 label: (args["label"] as? String) ?? "",
                 detail: (args["detail"] as? String) ?? "")
  }

  private static func staleDate(_ args: [String: Any]) -> Date? {
    guard let ms = (args["staleMs"] as? NSNumber)?.doubleValue else { return nil }
    return Date(timeIntervalSince1970: ms / 1000)
  }

  private static func start(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(FlutterError(code: "disabled", message: "Live Activities are disabled by the user", details: nil))
      return
    }
    guard let kind = args["kind"] as? String, kind == "EVENT" || kind == "EXAM",
          let refId = (args["refId"] as? NSNumber)?.int64Value,
          let title = args["title"] as? String, let state = state(from: args) else {
      result(FlutterError(code: "bad_args", message: "Invalid live activity arguments", details: nil))
      return
    }
    // Ayni sey icin ikinci kopya acilmaz: varsa guncellenir.
    if let existing = Activity<BuLiveActivityAttributes>.activities.first(where: { $0.attributes.kind == kind && $0.attributes.refId == refId }) {
      Task {
        await existing.update(ActivityContent(state: state, staleDate: staleDate(args)))
        result(["activityId": existing.id])
      }
      return
    }
    do {
      let attrs = BuLiveActivityAttributes(kind: kind, refId: refId, title: title)
      let activity = try Activity.request(
        attributes: attrs,
        content: ActivityContent(state: state, staleDate: staleDate(args)),
        pushType: .token)
      observe(activity)
      result(["activityId": activity.id])
    } catch {
      result(FlutterError(code: "request_failed", message: "\(error)", details: nil))
    }
  }

  /// Uygulama yeniden acilinca sistemde suren etkinlikler icin jeton/durum dinleyicileri kurulur.
  static func reattach() {
    for activity in Activity<BuLiveActivityAttributes>.activities { observe(activity) }
  }

  private static func observe(_ activity: Activity<BuLiveActivityAttributes>) {
    let id = activity.id
    observers[id]?.cancel()
    observers[id] = Task {
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          for await data in activity.pushTokenUpdates {
            let token = data.map { String(format: "%02x", $0) }.joined()
            BuLiveActivityBridge.sendToken(activityId: id, token: token)
          }
        }
        group.addTask {
          for await s in activity.activityStateUpdates where s == .ended || s == .dismissed {
            BuLiveActivityBridge.sendEnded(activityId: id)
            return
          }
        }
      }
    }
  }
}

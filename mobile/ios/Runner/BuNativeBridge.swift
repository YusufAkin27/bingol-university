import Flutter
import UIKit
import UserNotifications

/// iOS yerel köprüsü (Android'deki MainActivity + LocalReminders.kt karşılığı). İki kanal:
///
/// - `bu_kampus/notify`: ders/sınav yerel hatırlatmaları (UNUserNotificationCenter ile zamanlanır; sunucu
///   göndermez). Yöntemler Dart'taki `ChannelReminderBackend` ile aynıdır: replaceGroup, upsert, cancel, cancelGroup,
///   cancelAll, notificationsAllowed, takeLaunchPayload; dokunuşta Dart'a `onTap` gönderilir.
///   Android'e özgü yöntemler (setChannelNames, pushDiagnostics, openBatterySettings...) BİLEREK yoktur:
///   `FlutterMethodNotImplemented` Dart'ta MissingPluginException olur ve orada yakalanır.
/// - `bu_kampus/badge`: uygulama simgesi rozet sayısı. Sunucu APNs `badge` alanına okunmamış bildirim sayısını
///   yazar ama istemci okununca sıfırlamazsa rozet takılı kalır; Dart (`IconBadge`) güncel sayıyı buraya gönderir.
///
/// UYARI: Bu dosya Windows'ta derlenemedi (macOS/Xcode gerekir); ilk macOS derlemesinde doğrulayın
/// (docs/IOS_RELEASE.md bölüm 9). Firebase Messaging eklentisiyle birlikte çalışır: yalnızca `buLocal`
/// işaretli kendi yerel bildirimlerimize yanıt verir, FCM bildirimlerine dokunmaz (çift tamamlayıcı çağrısı olmasın).
final class BuNativeBridge: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
  private static let idPrefix = "bu."
  private static let localKey = "buLocal"
  private static let payloadKey = "buPayload"
  /// Dart'ın dinleyicisi hazır olmadan gelen dokunuş (soğuk açılış) bu süre içinde `takeLaunchPayload` ile alınabilir.
  private static let pendingTtl: TimeInterval = 120

  /// Eklenti temsilcileri zayıf tutulduğu için güçlü referans burada durur.
  private static var shared: BuNativeBridge?

  private let notifyChannel: FlutterMethodChannel
  private var dartReady = false
  private var pending: (payload: [String: String], at: Date)?

  private init(notifyChannel: FlutterMethodChannel) {
    self.notifyChannel = notifyChannel
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let notify = FlutterMethodChannel(name: "bu_kampus/notify", binaryMessenger: messenger)
    let badge = FlutterMethodChannel(name: "bu_kampus/badge", binaryMessenger: messenger)
    let instance = BuNativeBridge(notifyChannel: notify)
    shared = instance
    notify.setMethodCallHandler { call, result in instance.handleNotify(call, result) }
    badge.setMethodCallHandler { call, result in BuNativeBridge.handleBadge(call, result) }
    // KVKK "verilerimi indir": JSON dosyası sistem paylaşım sayfasıyla verilir, pano kullanılmaz.
    let share = FlutterMethodChannel(name: "bu_kampus/share", binaryMessenger: messenger)
    share.setMethodCallHandler { call, result in BuNativeBridge.handleShare(call, result) }
    registrar.addApplicationDelegate(instance)
  }

  // MARK: - Dosya paylaşımı

  /// `shareFile {path}`: yalnız önbellek altındaki `export/` dizinindeki dosya paylaşılır (başka yol reddedilir).
  private static func handleShare(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard call.method == "shareFile" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
      result(FlutterError(code: "BAD_ARGS", message: "path", details: nil))
      return
    }
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let okDir = url.deletingLastPathComponent().lastPathComponent == "export"
    guard okDir, FileManager.default.fileExists(atPath: url.path) else {
      result(FlutterError(code: "FORBIDDEN_PATH", message: "export dışı dosya", details: nil))
      return
    }
    DispatchQueue.main.async {
      var top = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow }) }
        .first?.rootViewController
      while let presented = top?.presentedViewController { top = presented }
      guard let host = top else {
        result(FlutterError(code: "NO_VIEW", message: nil, details: nil))
        return
      }
      let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      // iPad: açılır pencere bir kaynağa bağlanmalı, yoksa çöker.
      if let pop = sheet.popoverPresentationController {
        pop.sourceView = host.view
        pop.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 0, height: 0)
        pop.permittedArrowDirections = []
      }
      host.present(sheet, animated: true) { result(true) }
    }
  }

  // MARK: - Rozet

  private static func handleBadge(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard call.method == "set" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any]
    let count = max(0, (args?["count"] as? NSNumber)?.intValue ?? 0)
    DispatchQueue.main.async {
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in result(nil) }
      } else {
        UIApplication.shared.applicationIconBadgeNumber = count
        result(nil)
      }
    }
  }

  // MARK: - Yerel hatırlatmalar

  private func handleNotify(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "replaceGroup":
      guard let group = args?["group"] as? String else {
        result(nil)
        return
      }
      let items = (args?["items"] as? [[String: Any]]) ?? []
      removePending(where: { $0.hasPrefix(self.groupPrefix(group)) }) {
        self.schedule(group: group, items: items) { self.finish(result, nil) }
      }
    case "upsert":
      guard let group = args?["group"] as? String, let item = args?["item"] as? [String: Any] else {
        result(nil)
        return
      }
      let id = (item["id"] as? NSNumber)?.intValue ?? 0
      removePending(where: { $0 == self.identifier(group, id) }) {
        self.schedule(group: group, items: [item]) { self.finish(result, nil) }
      }
    case "cancel":
      guard let group = args?["group"] as? String, let id = (args?["id"] as? NSNumber)?.intValue else {
        result(nil)
        return
      }
      removePending(where: { $0 == self.identifier(group, id) }) { self.finish(result, nil) }
    case "cancelGroup":
      guard let group = args?["group"] as? String else {
        result(nil)
        return
      }
      removePending(where: { $0.hasPrefix(self.groupPrefix(group)) }) { self.finish(result, nil) }
    case "cancelAll":
      removePending(where: { $0.hasPrefix(BuNativeBridge.idPrefix) }) { self.finish(result, nil) }
    case "notificationsAllowed":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let status = settings.authorizationStatus
        let ok = status == .authorized || status == .provisional
        self.finish(result, ok)
      }
    case "takeLaunchPayload":
      // Dart dinleyicisini kurduktan sonra çağırır: bundan sonraki dokunuşlar doğrudan `onTap` ile gider.
      dartReady = true
      var out: [String: String]?
      if let p = pending, Date().timeIntervalSince(p.at) < BuNativeBridge.pendingTtl {
        out = p.payload
      }
      pending = nil
      result(out)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func finish(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private func groupPrefix(_ group: String) -> String {
    return BuNativeBridge.idPrefix + group + "."
  }

  private func identifier(_ group: String, _ id: Int) -> String {
    return groupPrefix(group) + String(id)
  }

  /// Kimliği koşulu sağlayan bekleyen yerel bildirimleri siler (FCM bildirimleri bekleyen listede olmaz).
  private func removePending(where matches: @escaping (String) -> Bool, completion: @escaping () -> Void) {
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let ids = requests.map { $0.identifier }.filter(matches)
      if !ids.isEmpty {
        center.removePendingNotificationRequests(withIdentifiers: ids)
      }
      completion()
    }
  }

  /// Geçmiş zamanlıları atlar; iOS en çok 64 bekleyen yerel bildirim tutar (Dart tarafı grup başına 60 ile sınırlar).
  private func schedule(group: String, items: [[String: Any]], completion: @escaping () -> Void) {
    let center = UNUserNotificationCenter.current()
    let dispatchGroup = DispatchGroup()
    for item in items {
      guard let id = (item["id"] as? NSNumber)?.intValue,
            let atMs = (item["at"] as? NSNumber)?.doubleValue else { continue }
      let interval = Date(timeIntervalSince1970: atMs / 1000.0).timeIntervalSinceNow
      if interval < 1 { continue }

      let content = UNMutableNotificationContent()
      content.title = (item["title"] as? String) ?? ""
      content.body = (item["body"] as? String) ?? ""
      content.sound = UNNotificationSound.default
      content.threadIdentifier = group
      var payload: [String: String] = [:]
      if let raw = item["payload"] as? [String: Any] {
        for (key, value) in raw { payload[key] = "\(value)" }
      }
      content.userInfo = [BuNativeBridge.localKey: true, BuNativeBridge.payloadKey: payload]

      // Mutlak süreli tetikleyici: saat dilimi değişse de an kaymaz.
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
      let request = UNNotificationRequest(identifier: identifier(group, id), content: content, trigger: trigger)
      dispatchGroup.enter()
      center.add(request) { _ in dispatchGroup.leave() }
    }
    dispatchGroup.notify(queue: .main) { completion() }
  }

  // MARK: - UNUserNotificationCenterDelegate (yalnız kendi yerel bildirimlerimiz)

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    guard notification.request.content.userInfo[BuNativeBridge.localKey] != nil else { return }
    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let info = response.notification.request.content.userInfo
    guard info[BuNativeBridge.localKey] != nil else { return }
    var payload: [String: String] = [:]
    if let raw = info[BuNativeBridge.payloadKey] as? [String: Any] {
      for (key, value) in raw { payload[key] = "\(value)" }
    }
    if dartReady {
      notifyChannel.invokeMethod("onTap", arguments: payload)
    } else {
      pending = (payload: payload, at: Date())
    }
    completionHandler()
  }
}

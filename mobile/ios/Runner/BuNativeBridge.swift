import Flutter
import UIKit
import UserNotifications

/// iOS yerel köprüsü (Android'deki MainActivity + LocalReminders.kt karşılığı). Ekran koruması kanalı `bu_kampus/secure`
/// dosya sonundaki BuSecureView'dadır; aşağıdaki iki kanal:
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
  private let pushChannel: FlutterMethodChannel
  private var pushReady = false
  private static var remotePending: [String: String]?

  static func handleRemoteResponse(_ response: UNNotificationResponse) {
    var payload: [String: String] = [:]
    for (key, value) in response.notification.request.content.userInfo {
      if let key = key as? String, let value = value as? String { payload[key] = value }
    }
    payload["notificationAction"] = String(response.actionIdentifier.dropFirst(3))
    payload["notificationTag"] = response.notification.request.identifier
    payload["actionId"] = UUID().uuidString
    if let text = response as? UNTextInputNotificationResponse { payload["replyText"] = text.userText }
    if let bridge = shared, bridge.pushReady {
      bridge.pushChannel.invokeMethod("onTap", arguments: payload)
    } else { remotePending = payload }
  }
  private var dartReady = false
  private var pending: (payload: [String: String], at: Date)?

  private init(notifyChannel: FlutterMethodChannel, pushChannel: FlutterMethodChannel) {
    self.notifyChannel = notifyChannel
    self.pushChannel = pushChannel
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let notify = FlutterMethodChannel(name: "bu_kampus/notify", binaryMessenger: messenger)
    let badge = FlutterMethodChannel(name: "bu_kampus/badge", binaryMessenger: messenger)
    let push = FlutterMethodChannel(name: "bu_kampus/push_actions", binaryMessenger: messenger)
    let instance = BuNativeBridge(notifyChannel: notify, pushChannel: push)
    push.setMethodCallHandler { call, result in
      switch call.method {
      case "takeLaunchPayload":
        instance.pushReady = true
        result(remotePending); remotePending = nil
      case "clear":
        instance.pushReady = false; remotePending = nil
        UNUserNotificationCenter.current().removeAllDeliveredNotifications(); result(nil)
      case "dismiss":
        if let args = call.arguments as? [String: Any], let tag = args["tag"] as? String {
          UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [tag])
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
    shared = instance
    notify.setMethodCallHandler { call, result in instance.handleNotify(call, result) }
    badge.setMethodCallHandler { call, result in BuNativeBridge.handleBadge(call, result) }
    // KVKK "verilerimi indir": JSON dosyası sistem paylaşım sayfasıyla verilir, pano kullanılmaz.
    let share = FlutterMethodChannel(name: "bu_kampus/share", binaryMessenger: messenger)
    share.setMethodCallHandler { call, result in BuNativeBridge.handleShare(call, result) }
    // Tek gösterimlik fotoğraf görüntüleyicisi için ekran koruması (BuSecureView, dosya sonunda).
    let secure = FlutterMethodChannel(name: "bu_kampus/secure", binaryMessenger: messenger)
    BuSecureView.shared.attach(secure)
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

// MARK: - Tek gösterimlik fotoğraf için ekran koruması (kanal `bu_kampus/secure`)

/// Görüntüleyici açıkken çağrılan `enable`, kapanınca `disable`. iOS'ta ekran görüntüsünü doğrudan ENGELLEYEN resmî
/// API yoktur; burada dört katman vardır (hepsi en iyi çabadır, hiçbiri tek başına garanti değildir):
///
/// 1. Güvenli katman: pencere katmanı, `isSecureTextEntry = true` olan bir `UITextField`'ın iç katmanına taşınır.
///    Sistem bu katmanı ekran görüntüsü/ekran kaydı/AirPlay çıktısında SİYAH çizer (DRM benzeri; resmî olmayan, ama
///    yaygın kullanılan yöntem; iOS sürümleriyle iç katman düzeni değişebilir). Katman bulunamazsa ya da taşıma
///    doğrulanamazsa her şey eski haline döner ve `secureLayer=false` bildirilir: uygulama çalışmaya devam eder.
/// 2. `UIScreen.isCaptured` + `capturedDidChangeNotification`: kayıt/yansıtma başlayınca Dart'a `onCaptured`.
/// 3. `userDidTakeScreenshotNotification`: ekran görüntüsü ALINDIKTAN SONRA Dart'a `onScreenshot` (engelleyemez).
/// 4. `willResignActive`: uygulama değiştirici önizlemesi için opak siyah örtü; `didBecomeActive`'de kalkar.
///
/// UYARI: macOS/Xcode'da derlenip denenmedi (docs/IOS_RELEASE.md).
final class BuSecureView: NSObject {
  static let shared = BuSecureView()

  private var channel: FlutterMethodChannel?
  private var enabled = false
  private var observers: [NSObjectProtocol] = []
  private var cover: UIView?

  // Güvenli katman durumu (kurulduysa geri almak için başvurular güçlü tutulur).
  private var field: UITextField?
  private var hostLayer: CALayer?
  private var installedWindow: UIWindow?

  func attach(_ channel: FlutterMethodChannel) {
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "enable":
        DispatchQueue.main.async { result(self.enable()) }
      case "disable":
        DispatchQueue.main.async {
          self.disable()
          result(nil)
        }
      case "isCaptured":
        DispatchQueue.main.async { result(self.isCaptured()) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func keyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })
  }

  private func isCaptured() -> Bool {
    if let screen = keyWindow()?.screen { return screen.isCaptured }
    return UIScreen.main.isCaptured
  }

  private func enable() -> [String: Any] {
    if !enabled {
      enabled = true
      addObservers()
    }
    let layered = installSecureLayer()
    return ["secureLayer": layered, "captured": isCaptured()]
  }

  private func disable() {
    guard enabled else { return }
    enabled = false
    for token in observers { NotificationCenter.default.removeObserver(token) }
    observers.removeAll()
    hideCover()
    removeSecureLayer()
  }

  // MARK: Güvenli katman

  private func installSecureLayer() -> Bool {
    if installedWindow != nil { return true }
    guard let window = keyWindow(), let host = window.layer.superlayer else { return false }
    let tf = UITextField()
    tf.isUserInteractionEnabled = false
    tf.translatesAutoresizingMaskIntoConstraints = false
    tf.isSecureTextEntry = true
    window.addSubview(tf)
    tf.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
    tf.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
    tf.layoutIfNeeded()
    host.addSublayer(tf.layer)
    // İç güvenli katman: iOS 17 ve sonrasında son alt katman, öncesinde ilki.
    let inner: CALayer?
    if #available(iOS 17.0, *) {
      inner = tf.layer.sublayers?.last
    } else {
      inner = tf.layer.sublayers?.first
    }
    guard let container = inner else {
      tf.layer.removeFromSuperlayer()
      tf.removeFromSuperview()
      return false
    }
    container.addSublayer(window.layer)
    guard window.layer.superlayer === container else {
      // Taşıma tutmadı: pencere katmanını eski yerine koy, geçici nesneleri sök.
      host.addSublayer(window.layer)
      tf.layer.removeFromSuperlayer()
      tf.removeFromSuperview()
      return false
    }
    field = tf
    hostLayer = host
    installedWindow = window
    return true
  }

  private func removeSecureLayer() {
    guard let window = installedWindow, let host = hostLayer, let tf = field else { return }
    host.addSublayer(window.layer)
    tf.isSecureTextEntry = false
    tf.layer.removeFromSuperlayer()
    tf.removeFromSuperview()
    field = nil
    hostLayer = nil
    installedWindow = nil
  }

  // MARK: Gözlemciler

  private func addObservers() {
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
      guard let self = self else { return }
      self.channel?.invokeMethod("onCaptured", arguments: ["captured": self.isCaptured()])
    })
    observers.append(center.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main) { [weak self] _ in
      self?.channel?.invokeMethod("onScreenshot", arguments: nil)
    })
    observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.showCover()
    })
    observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.hideCover()
    })
  }

  /// Uygulama değiştirici anlık görüntüsü alınmadan önce içeriği opak örtüyle kapatır.
  private func showCover() {
    guard cover == nil, let window = keyWindow() else { return }
    let view = UIView(frame: window.bounds)
    view.backgroundColor = .black
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.isUserInteractionEnabled = false
    window.addSubview(view)
    cover = view
  }

  private func hideCover() {
    cover?.removeFromSuperview()
    cover = nil
  }
}

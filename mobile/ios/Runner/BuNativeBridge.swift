import AVFoundation
import Flutter
import UIKit
import UserNotifications

/// iOS yerel köprüsü (Android'deki MainActivity + LocalReminders.kt karşılığı). Ekran koruması kanalı `bu_kampus/secure`
/// (BuSecureView) ve video kapak karesi kanalı `bu_kampus/video_frame` (BuVideoFrames) dosya sonundadır; aşağıdaki iki kanal:
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
    // Video kapak karesi (gönderirken yerel dosyadan, gösterirken yetkili ağ adresinden): BuVideoFrames, dosya sonunda.
    BuVideoFrames.register(with: messenger)
    // Video kırpma (AVAssetExportSession, yeniden kodlamadan): lib/core/platform/video_trim.dart.
    BuVideoTrim.register(with: messenger)
    // Cihaz takvimine yazma (EventKit) ve alarm yedeği (yerel bildirim): BuCalendarAlarmBridge.swift.
    BuCalendarBridge.register(messenger: messenger)
    BuAlarmBridge.register(messenger: messenger)
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
/// 1. Güvenli katman (YALNIZ Dart `enable(layerTrick: true)` derse; varsayılan KAPALI): pencere katmanı,
///    `isSecureTextEntry = true` olan bir `UITextField`'ın iç katmanına taşınır. Sistem bu katmanı ekran
///    görüntüsü/ekran kaydı/AirPlay çıktısında SİYAH çizer (resmî olmayan, ama yaygın kalıp: ScreenProtectorKit).
///    RİSK: kalıp iOS sürümlerine ve alan yerleşimine bağlıdır; yanlış oturursa tüm pencere içeriği sağ-alta KAYAR
///    (kullanıcı gerçek iPhone'da gördü). Bu yüzden: (a) alan pencerede MERKEZLENİR, (b) taşımadan önce/sonra pencere
///    katmanının ekrandaki konumu ölçülür, fark varsa HEMEN geri alınır (`secureLayer=false`), (c) 0,4 sn ve 1,5 sn
///    sonra ve uygulama öne gelince yeniden ölçülür, kayma varsa geri alınır (`onLayerRevoked`).
/// 2. `UIScreen.isCaptured` (+ iOS 17'de `traitCollection.sceneCaptureState`) + `capturedDidChangeNotification`:
///    kayıt/yansıtma başlayınca native örtü HEMEN kapanır, ardından Dart'a `onCaptured` gider.
/// 3. `userDidTakeScreenshotNotification`: ekran görüntüsü ALINDIKTAN SONRA Dart'a `onScreenshot` (engelleyemez).
/// 4. `willResignActive`: uygulama değiştirici önizlemesi için opak siyah örtü; `didBecomeActive`'de kalkar.
///
/// 2-4 yerleşimi hiç değiştirmez. UYARI: macOS/Xcode'da derlenip denenmedi (docs/IOS_RELEASE.md).
final class BuSecureView: NSObject {
  static let shared = BuSecureView()

  private var channel: FlutterMethodChannel?
  private var enabled = false
  private var observers: [NSObjectProtocol] = []
  private var cover: UIView?
  private var coverReasons = Set<String>()
  private var lastScreenshotAt: Date?

  // Güvenli katman durumu (kurulduysa geri almak için başvurular güçlü tutulur).
  private var field: UITextField?
  private var hostLayer: CALayer?
  private var hostIndex: Int?
  private var installedWindow: UIWindow?

  /// Pencere katmanının yerleşim özeti: taşımadan önce/sonra karşılaştırılır.
  private struct Geometry {
    let frame: CGRect
    let bounds: CGRect
    let origin: CGPoint

    init(_ window: UIWindow) {
      frame = window.frame
      bounds = window.bounds
      var root: CALayer = window.layer
      // Sınırlı döngü: beklenmedik/dairesel katman zincirinde sonsuz dönmesin.
      var depth = 0
      while let up = root.superlayer, depth < 64 {
        root = up
        depth += 1
      }
      origin = window.layer.convert(CGPoint.zero, to: root)
    }

    func matches(_ other: Geometry) -> Bool {
      let tol: CGFloat = 0.5
      return abs(origin.x - other.origin.x) <= tol && abs(origin.y - other.origin.y) <= tol
        && abs(frame.minX - other.frame.minX) <= tol && abs(frame.minY - other.frame.minY) <= tol
        && abs(frame.width - other.frame.width) <= tol && abs(frame.height - other.frame.height) <= tol
        && abs(bounds.width - other.bounds.width) <= tol && abs(bounds.height - other.bounds.height) <= tol
    }
  }

  private var baseline: Geometry?

  func attach(_ channel: FlutterMethodChannel) {
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "enable":
        let args = call.arguments as? [String: Any]
        let trick = (args?["layerTrick"] as? Bool) ?? false
        DispatchQueue.main.async { result(self.enable(layerTrick: trick)) }
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

  /// Ekran kaydı/yansıtma/AirPlay sürüyor mu. iOS 17+: pencerenin sahnesi için `sceneCaptureState` (Apple belgesi:
  /// "scene is currently being mirrored or recorded"); her sürümde yedek: `UIScreen.isCaptured`. İkisinden biri
  /// "yakalanıyor" derse yakalanıyor sayılır (güvenli yön).
  private func isCaptured() -> Bool {
    let window = keyWindow()
    if #available(iOS 17.0, *) {
      if let w = window, w.traitCollection.sceneCaptureState == .active { return true }
    }
    if let screen = window?.screen { return screen.isCaptured }
    return UIScreen.main.isCaptured
  }

  private func enable(layerTrick: Bool) -> [String: Any] {
    if !enabled {
      enabled = true
      addObservers()
    }
    // Güvenli katman yalnız açıkça istenirse kurulur (yerleşimi kaydırma riski: sınıf açıklamasına bakın).
    let layered = layerTrick ? installSecureLayer() : false
    let captured = isCaptured()
    // Açılışta zaten yakalanıyorsa örtü Dart yanıtını beklemeden kapanır.
    if captured { showCover("capture") }
    return ["secureLayer": layered, "captured": captured]
  }

  private func disable() {
    guard enabled else { return }
    enabled = false
    for token in observers { NotificationCenter.default.removeObserver(token) }
    observers.removeAll()
    clearCover()
    // Ekran görüntüsü işlemi sürerken katman SÖKÜLMEZ: yeniden yerleştirme o sırada UIKit'te çökme riski taşır.
    // Son ekran görüntüsünden bu yana kısa süre geçtiyse sökümü ertele (arada yeniden `enable` gelirse iptal).
    let wait = screenshotSettleDelay()
    if wait > 0 {
      DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
        guard let self = self, !self.enabled else { return }
        self.removeSecureLayer()
      }
    } else {
      removeSecureLayer()
    }
  }

  /// Son ekran görüntüsü olayından bu yana ekran görüntüsü işleminin bitmesi için beklenecek kalan süre (sn).
  private func screenshotSettleDelay() -> TimeInterval {
    guard let at = lastScreenshotAt else { return 0 }
    let remaining = 1.5 - Date().timeIntervalSince(at)
    return remaining > 0 ? remaining : 0
  }

  // MARK: Güvenli katman

  private func installSecureLayer() -> Bool {
    if installedWindow != nil { return true }
    guard let window = keyWindow(), let host = window.layer.superlayer else { return false }
    let before = Geometry(window)
    let index = host.sublayers?.firstIndex(where: { $0 === window.layer })

    let tf = UITextField()
    tf.isSecureTextEntry = true
    tf.isUserInteractionEnabled = false
    tf.translatesAutoresizingMaskIntoConstraints = false
    window.addSubview(tf)
    // Alan pencerede MERKEZLENMELİ; aksi halde tüm pencere içeriği sağ-alta kayar.
    tf.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
    tf.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
    window.layoutIfNeeded()
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
      restore(window: window, host: host, index: index, field: tf)
      return false
    }
    field = tf
    hostLayer = host
    hostIndex = index
    installedWindow = window
    baseline = before
    // Kayma denetimi: pencerenin ekrandaki konumu/boyutu değiştiyse HEMEN geri al.
    if !Geometry(window).matches(before) {
      removeSecureLayer()
      return false
    }
    for delay in [0.4, 1.5] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        guard let self = self, self.enabled else { return }
        self.verifyLayer()
      }
    }
    return true
  }

  /// Kurulu güvenli katman varken pencere kaymışsa katmanı geri alır ve Dart'a haber verir.
  private func verifyLayer() {
    guard enabled, let window = installedWindow, let before = baseline else { return }
    // Ekran görüntüsü işlemi sürerken katman değiştirilmez; bir sonraki doğrulama (öne gelince) yeniden dener.
    if screenshotSettleDelay() > 0 { return }
    if !Geometry(window).matches(before) {
      removeSecureLayer()
      channel?.invokeMethod("onLayerRevoked", arguments: nil)
    }
  }

  private func restore(window: UIWindow, host: CALayer, index: Int?, field tf: UITextField) {
    // Dizin sınırı doğrulanır; negatif/büyük değer UInt32 dönüşümünde çökertmesin.
    let count = host.sublayers?.count ?? 0
    if let i = index, i >= 0, i <= count, let at = UInt32(exactly: i) {
      host.insertSublayer(window.layer, at: at)
    } else {
      host.addSublayer(window.layer)
    }
    tf.isSecureTextEntry = false
    tf.layer.removeFromSuperlayer()
    tf.removeFromSuperview()
  }

  private func removeSecureLayer() {
    guard let window = installedWindow, let host = hostLayer, let tf = field else { return }
    restore(window: window, host: host, index: hostIndex, field: tf)
    field = nil
    hostLayer = nil
    hostIndex = nil
    installedWindow = nil
    baseline = nil
  }

  // MARK: Gözlemciler

  private func addObservers() {
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
      guard let self = self else { return }
      let captured = self.isCaptured()
      // Yakalama başladıysa opak örtü HEMEN kapanır (Dart olayı asenkron kanaldan gelir; o ana kadar kare sızmasın).
      // Bitince örtü kalkar; yeniden açma hakkını Dart/sunucu belirler (tüketilmiş fotoğraf yeniden istenmez).
      if captured { self.showCover("capture") } else { self.hideCover("capture") }
      self.channel?.invokeMethod("onCaptured", arguments: ["captured": captured])
    })
    observers.append(center.addObserver(forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main) { [weak self] _ in
      // YALNIZ Dart'a haber verir; burada katman/örtü değiştirilmez (ekran görüntüsü işlemi sürüyor olabilir).
      self?.lastScreenshotAt = Date()
      self?.channel?.invokeMethod("onScreenshot", arguments: nil)
    })
    observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
      self?.showCover("inactive")
    })
    observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
      guard let self = self else { return }
      self.hideCover("inactive")
      // Arka planda yakalama durumu değişmiş olabilir.
      if self.isCaptured() { self.showCover("capture") } else { self.hideCover("capture") }
      self.verifyLayer()
    })
  }

  /// İçeriği opak örtüyle kapatır (uygulama değiştirici anlık görüntüsü, ekran kaydı/yansıtma). Örtü, tüm nedenler
  /// ([coverReasons]) kalkana kadar durur: yakalama bitse de uygulama hâlâ etkin değilse örtü kalkmaz.
  private func showCover(_ reason: String) {
    coverReasons.insert(reason)
    guard cover == nil, let window = keyWindow() else { return }
    let view = UIView(frame: window.bounds)
    view.backgroundColor = .black
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.isUserInteractionEnabled = false
    window.addSubview(view)
    cover = view
  }

  private func hideCover(_ reason: String) {
    coverReasons.remove(reason)
    guard coverReasons.isEmpty else { return }
    cover?.removeFromSuperview()
    cover = nil
  }

  private func clearCover() {
    coverReasons.removeAll()
    cover?.removeFromSuperview()
    cover = nil
  }
}

// MARK: - Video kapak karesi (kanal `bu_kampus/video_frame`)

/// `frame {path | url, headers, positionMs, maxEdge, quality}` -> JPEG baytları (alınamazsa null).
/// Yerel dosya (`path`, gönderirken) ya da yetkili ağ adresi (`url` + `headers`, eski mesajlarda kapak üretirken).
/// `AVAssetImageGenerator`: dönüş (rotasyon) uygulanır, uzun kenar `maxEdge`'i aşmaz, en yakın anahtar kare alınır
/// (tolerans sonsuz: ağ akışında hızlı ve güvenilir). İstenen an videodan uzunsa 0. saniyeye düşülür.
/// UYARI: macOS/Xcode'da derlenip denenmedi.
enum BuVideoFrames {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "bu_kampus/video_frame", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "frame" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "BAD_ARGS", message: "args", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let data = grab(args)
        DispatchQueue.main.async {
          if let data = data { result(FlutterStandardTypedData(bytes: data)) } else { result(nil) }
        }
      }
    }
  }

  private static func grab(_ args: [String: Any]) -> Data? {
    let asset: AVURLAsset
    if let path = args["path"] as? String, !path.isEmpty {
      asset = AVURLAsset(url: URL(fileURLWithPath: path))
    } else if let raw = args["url"] as? String, let url = URL(string: raw),
              url.scheme == "https" || url.scheme == "http" {
      var options: [String: Any] = [:]
      if let headers = args["headers"] as? [String: String], !headers.isEmpty {
        options["AVURLAssetHTTPHeaderFieldsKey"] = headers
      }
      asset = AVURLAsset(url: url, options: options)
    } else {
      return nil
    }
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .positiveInfinity
    generator.requestedTimeToleranceAfter = .positiveInfinity
    let edge = CGFloat(max(160, min(1280, (args["maxEdge"] as? NSNumber)?.intValue ?? 720)))
    generator.maximumSize = CGSize(width: edge, height: edge)
    let quality = CGFloat(max(0.3, min(0.95, (args["quality"] as? NSNumber)?.doubleValue ?? 0.8)))
    let positionMs = max(0, (args["positionMs"] as? NSNumber)?.int64Value ?? 500)
    var times = [CMTime(value: positionMs, timescale: 1000)]
    if positionMs > 0 { times.append(.zero) }
    for time in times {
      var actual = CMTime.zero
      if let image = try? generator.copyCGImage(at: time, actualTime: &actual),
         let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: quality) {
        return jpeg
      }
    }
    return nil
  }
}

// MARK: - Video kırpma (kanal `bu_kampus/video_trim`)

/// `trim {path, startMs, endMs, maxMs}` -> yeni mp4/mov dosyasının yolu (`tmp/video_trim/`).
/// `AVAssetExportSession` + `AVAssetExportPresetPassthrough`: yeniden kodlamadan, yalnız `timeRange` kesilir (başlangıç
/// en yakın anahtar kareye oturur, süre birkaç yüz ms oynayabilir). `maxMs` > 0 ise çıktı başlangıç + maxMs'i aşmaz.
/// Hata: `BAD_ARGS` ya da `FAILED`. UYARI: macOS/Xcode'da derlenip denenmedi.
enum BuVideoTrim {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "bu_kampus/video_trim", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "trim" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String, !path.isEmpty,
            let startMs = (args["startMs"] as? NSNumber)?.int64Value,
            let endMs = (args["endMs"] as? NSNumber)?.int64Value,
            startMs >= 0, endMs > startMs else {
        result(FlutterError(code: "BAD_ARGS", message: "args", details: nil))
        return
      }
      let maxMs = (args["maxMs"] as? NSNumber)?.int64Value ?? 0
      let cap = maxMs > 0 ? min(endMs, startMs + maxMs) : endMs
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
        result(FlutterError(code: "FAILED", message: "session", details: nil))
        return
      }
      let dir = FileManager.default.temporaryDirectory.appendingPathComponent("video_trim", isDirectory: true)
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      removeStale(in: dir)
      let fileType: AVFileType = export.supportedFileTypes.contains(.mp4) ? .mp4 : .mov
      let ext = fileType == .mp4 ? "mp4" : "mov"
      let out = dir.appendingPathComponent("trim_\(UUID().uuidString).\(ext)")
      export.outputURL = out
      export.outputFileType = fileType
      export.shouldOptimizeForNetworkUse = true
      export.timeRange = CMTimeRange(
        start: CMTime(value: startMs, timescale: 1000),
        end: CMTime(value: cap, timescale: 1000))
      export.exportAsynchronously {
        DispatchQueue.main.async {
          if export.status == .completed {
            result(out.path)
          } else {
            try? FileManager.default.removeItem(at: out)
            result(FlutterError(code: "FAILED", message: export.error?.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  /// Eski kesim dosyalarını (6 saatten eski) temizler.
  private static func removeStale(in dir: URL) {
    let keys: [URLResourceKey] = [.contentModificationDateKey]
    guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys) else { return }
    let limit = Date().addingTimeInterval(-6 * 3600)
    for file in files {
      if let date = (try? file.resourceValues(forKeys: Set(keys)))?.contentModificationDate, date < limit {
        try? FileManager.default.removeItem(at: file)
      }
    }
  }
}

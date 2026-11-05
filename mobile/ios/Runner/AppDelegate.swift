import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Push: bildirim merkezi delegesi (on plan sunumu firebase_messaging eklentisine yonlenir; Dart tarafi
    // on planda sistem seridini kapatir). APNs belirteci kaydi + FCM eslemesi eklentinin
    // FirebaseAppDelegateProxy (swizzling, varsayilan acik) mekanizmasiyla yapilir; Info.plist'e
    // FirebaseAppDelegateProxyEnabled=NO EKLEMEYIN. GoogleService-Info.plist yoksa bu satirlar zararsizdir.
    UNUserNotificationCenter.current().delegate = self
    registerPushCategories()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if response.actionIdentifier == "bu.ack" &&
       response.notification.request.content.categoryIdentifier.hasPrefix("BU_") {
      // "Anladim": yalniz bildirimi kapatir (iOS aksiyona dokununca bildirimi zaten kaldirir); uygulama acilmaz.
      completionHandler()
      return
    }
    if response.actionIdentifier.hasPrefix("bu.") &&
       response.notification.request.content.categoryIdentifier.hasPrefix("BU_") {
      BuNativeBridge.handleRemoteResponse(response)
      completionHandler()
      return
    }
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  private func registerPushCategories() {
    let lang = Locale.preferredLanguages.first ?? "tr"
    func label(_ tr: String, _ en: String, _ ar: String) -> String {
      lang.hasPrefix("ar") ? ar : lang.hasPrefix("en") ? en : tr
    }
    func action(_ id: String, _ tr: String, _ en: String, _ ar: String) -> UNNotificationAction {
      UNNotificationAction(identifier: "bu." + id, title: label(tr, en, ar), options: [.foreground, .authenticationRequired])
    }
    // Uygulamayi acmadan yalniz bildirimi kapatan aksiyon ("Anladim"); AppDelegate `bu.ack`i dogrudan tamamlar.
    let ack = UNNotificationAction(identifier: "bu.ack", title: label("Anladım", "Got it", "فهمت"), options: [])
    // Kirmizi (yikici stil) "Bu ben degilim": hesap guvenligi sayfasini acar (orada tum oturumlar kapatilabilir).
    let notMe = UNNotificationAction(identifier: "bu.security", title: label("Bu ben değilim", "This wasn't me", "لم أكن أنا"),
      options: [.foreground, .authenticationRequired, .destructive])
    let reply = UNTextInputNotificationAction(identifier: "bu.reply", title: label("Yanıtla", "Reply", "رد"),
      options: [.foreground, .authenticationRequired], textInputButtonTitle: label("Gönder", "Send", "إرسال"),
      textInputPlaceholder: label("Mesajınız", "Your message", "رسالتك"))
    let open = action("open", "Detay", "Details", "التفاصيل")
    let calendar = action("calendar", "Takvime Ekle", "Add to calendar", "إضافة للتقويم")
    let map = action("map", "Haritada Gör", "Show on map", "عرض الخريطة")
    let definitions: [String: [UNNotificationAction]] = [
      "CHAT_DIRECT": [reply, action("mark_read", "Okundu İşaretle", "Mark as read", "تحديد كمقروء")],
      "CHAT_GROUP": [reply, action("mute_hour", "1 Saat Sessize Al", "Mute for 1 hour", "كتم لساعة")],
      "CHAT_MEDIA": [action("open", "Görüntüle", "View", "عرض"), reply],
      "EVENT_REMINDER": [calendar, map],
      "EVENT_UPDATE": [ack, action("open", "Program Detayı", "Schedule details", "تفاصيل البرنامج")],
      "EVENT_ADMISSION": [action("open", "Giriş Kartı", "Entry pass", "بطاقة الدخول")],
      "EXAM": [action("open", "Sınav Detayı", "Exam details", "تفاصيل الامتحان")],
      "EVENT_CANCELLED": [open],
      "ACADEMIC": [open], "ANNOUNCEMENT": [open], "SYSTEM": [open], "MODERATION": [open],
      "POLL": [action("open", "Oy ver", "Vote", "تصويت")],
      "MEAL": [action("open", "Menüyü Gör", "View menu", "عرض القائمة")],
      "SOCIAL": [], "LIKE": [], "FOLLOW": [action("follow", "Takip et", "Follow", "متابعة")],
      "FOLLOW_REQUEST": [action("follow_accept", "Onayla", "Accept", "قبول"), action("follow_decline", "Reddet", "Decline", "رفض")],
      "FOLLOW_ACCEPTED": [action("open", "Profili Gör", "View profile", "عرض الملف")],
      "SECURITY": [notMe],
      "SUPPORT": [action("open", "Talebi Görüntüle", "View ticket", "عرض الطلب")]
    ]
    UNUserNotificationCenter.current().setNotificationCategories(Set(definitions.map { key, actions in
      UNNotificationCategory(identifier: "BU_" + key, actions: actions, intentIdentifiers: [], options: [])
    }))
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Yerel hatirlatmalar (bu_kampus/notify) + simge rozeti (bu_kampus/badge): bkz. BuNativeBridge.swift.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BuNativeBridge") {
      BuNativeBridge.register(with: registrar)
    }
  }
}

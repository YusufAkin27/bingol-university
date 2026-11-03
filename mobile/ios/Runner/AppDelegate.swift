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
      "EVENT_REMINDER": [calendar, map], "EVENT_UPDATE": [open], "EVENT_ADMISSION": [open],
      "EXAM": [open], "ACADEMIC": [open], "ANNOUNCEMENT": [open],
      "POLL": [action("open", "Oy ver", "Vote", "تصويت")],
      "MEAL": [action("open", "Menüyü Gör", "View menu", "عرض القائمة")],
      "SOCIAL": [open], "FOLLOW": [action("follow", "Takip et", "Follow", "متابعة")],
      "FOLLOW_REQUEST": [action("follow_accept", "Onayla", "Accept", "قبول"), action("follow_decline", "Reddet", "Decline", "رفض")],
      "FOLLOW_ACCEPTED": [action("open", "Profili Gör", "View profile", "عرض الملف")],
      "SECURITY": [action("security", "Hesap Güvenliği", "Account security", "أمان الحساب")],
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

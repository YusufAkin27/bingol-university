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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Yerel hatirlatmalar (bu_kampus/notify) + simge rozeti (bu_kampus/badge): bkz. BuNativeBridge.swift.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BuNativeBridge") {
      BuNativeBridge.register(with: registrar)
    }
  }
}

import Flutter
import UIKit
import CleverTapSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // CleverTap reads CleverTapAccountID / CleverTapToken / CleverTapRegion from Info.plist.
    // autoIntegrate() swizzles the push + lifecycle callbacks so the APNs device token and
    // incoming notifications are forwarded to CleverTap automatically (the iOS equivalent of
    // the Android manifest wiring we already have).
    CleverTap.autoIntegrate()

    // Register with APNs. The permission prompt itself is requested from Dart
    // (firebase_messaging requestPermission in main.dart).
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

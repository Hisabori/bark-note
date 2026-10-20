import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var alertsChannel: FlutterMethodChannel?
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "com.railtime/alerts", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    alertsChannel = channel
    channel.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      if call.method == "status" {
        center.getPendingNotificationRequests { requests in
          let epoch = requests.first(where: { $0.identifier == "departure" })?.content.userInfo["epoch"] as? NSNumber
          DispatchQueue.main.async { result(epoch ?? 0) }
        }
      } else if call.method == "cancel" {
        center.removePendingNotificationRequests(withIdentifiers: ["departure"])
        center.removeDeliveredNotifications(withIdentifiers: ["departure"])
        result(true)
      } else if call.method == "schedule" {
        guard let args = call.arguments as? [String: Any], let epoch = args["epoch"] as? NSNumber else { result(FlutterError(code: "TIME", message: "올바르지 않은 알림 시각", details: nil)); return }
        let target = Date(timeIntervalSince1970: epoch.doubleValue / 1000)
        guard target > Date() else { result(FlutterError(code: "TIME", message: "이미 지난 출발 시각", details: nil)); return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
          if let error = error { DispatchQueue.main.async { result(FlutterError(code: "PERMISSION", message: error.localizedDescription, details: nil)) }; return }
          guard granted else { DispatchQueue.main.async { result(false) }; return }
          let content = UNMutableNotificationContent()
          content.title = args["title"] as? String ?? "나갈 시간"
          content.body = args["body"] as? String ?? "출발 계획을 확인해주세요."
          content.sound = .default
          content.userInfo = ["epoch": epoch]
          let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, target.timeIntervalSinceNow), repeats: false)
          let request = UNNotificationRequest(identifier: "departure", content: content, trigger: trigger)
          center.add(request) { error in
            DispatchQueue.main.async {
              if let error = error { result(FlutterError(code: "ALARM", message: error.localizedDescription, details: nil)) }
              else { result(true) }
            }
          }
        }
      } else { result(FlutterMethodNotImplemented) }
    }
  }
}

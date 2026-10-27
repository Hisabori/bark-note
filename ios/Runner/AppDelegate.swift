import Flutter
import UIKit
import ActivityKit
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
      #if targetEnvironment(simulator)
      if call.method == "startupReady" {
        do {
          let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
          try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
          try "first-frame-rendered".write(to: folder.appendingPathComponent("startup-smoke-ready"), atomically: true, encoding: .utf8)
          result(true)
        } catch { result(FlutterError(code: "SMOKE", message: error.localizedDescription, details: nil)) }
        return
      }
      #endif
      if ["liveStart", "liveEnd", "liveStatus"].contains(call.method) {
        if #available(iOS 16.2, *) {
          DispatchQueue.main.async {
            let manager = DepartureLiveController.shared
            if call.method == "liveStart" { manager.start(call.arguments as? [String: Any] ?? [:], result: result) }
            else if call.method == "liveEnd" { manager.end(result: result) }
            else { manager.status(result: result) }
          }
        } else {
          if call.method == "liveStatus" { result(["active": false]) }
          else { result(call.method == "liveEnd") }
        }
        return
      }
      let center = UNUserNotificationCenter.current()
      if call.method == "status" {
        center.getPendingNotificationRequests { requests in
          let epoch = requests.first(where: { $0.identifier == "departure" })?.content.userInfo["epoch"] as? NSNumber
          DispatchQueue.main.async { result(epoch ?? 0) }
        }
      } else if call.method == "cancel" {
        center.removePendingNotificationRequests(withIdentifiers: ["departure"])
        center.removeDeliveredNotifications(withIdentifiers: ["departure"])
        if #available(iOS 16.2, *) {
          DispatchQueue.main.async { DepartureLiveController.shared.end(result: result) }
        } else { result(true) }
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


@available(iOS 16.2, *)
@MainActor
private final class DepartureLiveController {
  static let shared = DepartureLiveController()
  private var pending: Task<Void, Never>?
  private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
    let previous = pending
    pending = Task { @MainActor in
      await previous?.value
      await operation()
    }
  }
  func start(_ args: [String: Any], result: @escaping FlutterResult) {
    enqueue {
      guard ActivityAuthorizationInfo().areActivitiesEnabled,
        let leave = args["leaveEpoch"] as? NSNumber,
        let arrival = args["trainEpoch"] as? NSNumber,
        let expiry = args["staleEpoch"] as? NSNumber,
        let updated = args["updatedEpoch"] as? NSNumber else { result(false); return }
      let values = [leave, arrival, expiry, updated].map { $0.doubleValue / 1000 }
      guard values.allSatisfy({ $0.isFinite }) else { result(false); return }
      let now = Date()
      let leaveAt = Date(timeIntervalSince1970: values[0])
      let trainAt = Date(timeIntervalSince1970: values[1])
      let updatedAt = Date(timeIntervalSince1970: values[3])
      let staleAt = min(min(Date(timeIntervalSince1970: values[2]), leaveAt), trainAt)
      let kind = args["kind"] as? String ?? "train"
      let ttl: TimeInterval = kind == "route" ? 900 : 120
      let station = String((args["station"] as? String ?? "").prefix(80))
      let label = String((args["train"] as? String ?? "").prefix(160))
      guard ["train", "route"].contains(kind), !station.isEmpty, !label.isEmpty,
        leaveAt > now, leaveAt.timeIntervalSince(now) <= 8 * 3600,
        trainAt > leaveAt, staleAt > now, updatedAt <= now,
        now.timeIntervalSince(updatedAt) < ttl,
        staleAt <= updatedAt.addingTimeInterval(ttl) else { result(false); return }
      let attributes = DepartureAttributes(station: station, train: label, kind: kind)
      let state = DepartureAttributes.ContentState(leaveAt: leaveAt, trainAt: trainAt, updatedAt: updatedAt)
      let content = ActivityContent(state: state, staleDate: staleAt)
      let activities = Activity<DepartureAttributes>.activities
      if let current = activities.first(where: {
        ($0.activityState == .active || $0.activityState == .stale) &&
        $0.attributes.station == station && $0.attributes.train == label &&
        ($0.attributes.kind ?? "train") == kind
      }) {
        await current.update(content)
        for other in activities where other.id != current.id { await other.end(nil, dismissalPolicy: .immediate) }
        result(true)
      } else {
        do {
          _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
          for other in activities { await other.end(nil, dismissalPolicy: .immediate) }
          result(true)
        } catch { result(FlutterError(code: "ACTIVITY", message: "실시간 현황을 시작하지 못했습니다. 기기의 실시간 현황 설정을 확인해주세요.", details: nil)) }
      }
    }
  }
  func end(result: @escaping FlutterResult) {
    enqueue {
      for activity in Activity<DepartureAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
      result(true)
    }
  }
  func status(result: @escaping FlutterResult) {
    enqueue {
      guard let activity = Activity<DepartureAttributes>.activities.first(where: { $0.activityState == .active || $0.activityState == .stale }) else { result(["active": false]); return }
      result(["active": true, "kind": activity.attributes.kind ?? "train", "label": activity.attributes.train,
        "stale": activity.activityState == .stale, "staleEpoch": (activity.content.staleDate?.timeIntervalSince1970 ?? 0) * 1000, "leaveEpoch": activity.content.state.leaveAt.timeIntervalSince1970 * 1000])
    }
  }
}

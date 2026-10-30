import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    if #available(iOS 16.2, *) {
      Task { @MainActor in BarkLiveController.shared.end(result: { _ in }) }
    }
  }
}

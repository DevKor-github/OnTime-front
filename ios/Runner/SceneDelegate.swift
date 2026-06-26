import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let unhandledContexts = URLContexts.filter { context in
      !AppDelegate.handleAlarmLaunchURL(context.url)
    }

    if !unhandledContexts.isEmpty {
      super.scene(scene, openURLContexts: Set(unhandledContexts))
    }
  }
}

import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Held for the app's lifetime: the bridge owns the in-flight authorization
  // request and its delegate callbacks.
  private var appleSignInBridge: Any?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 13.0, *), let registrar = registrar(forPlugin: "AppleSignInBridge") {
      appleSignInBridge = AppleSignInBridge.register(with: registrar)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return super.application(app, open: url, options: options)
  }
}

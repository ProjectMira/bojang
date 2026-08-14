import AuthenticationServices
import Flutter
import UIKit

/// Runs Sign in with Apple through AuthenticationServices directly, the same
/// way the Drokpo app does, and — unlike the sign_in_with_apple plugin —
/// reports the *whole* NSError back to Dart.
///
/// That last part is the reason this file exists. The plugin forwards only
/// `ASAuthorizationError.Code` and `localizedDescription` and passes
/// `details: nil`, so Apple's `userInfo` — which carries the underlying
/// `AKAuthenticationError` — is discarded before Dart ever sees it. Apple
/// reports both a user dismissal and its own server-side refusal as code 1001,
/// so with the underlying error gone the two are indistinguishable, and every
/// failed sign-up for the last several builds has looked identical.
@available(iOS 13.0, *)
final class AppleSignInBridge: NSObject {
  static let channelName = "com.bojang.app/apple_sign_in"

  private var pendingResult: FlutterResult?
  private var controller: ASAuthorizationController?

  static func register(with registrar: FlutterPluginRegistrar) -> AppleSignInBridge {
    let bridge = AppleSignInBridge()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak bridge] call, result in
      bridge?.handle(call, result: result)
    }
    return bridge
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "requestCredential" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard pendingResult == nil else {
      result(
        FlutterError(
          code: "in-progress",
          message: "An Apple sign-in request is already running",
          details: nil
        )
      )
      return
    }

    let arguments = call.arguments as? [String: Any]
    let nonce = arguments?["nonce"] as? String

    let request = ASAuthorizationAppleIDProvider().createRequest()
    // Only the name: asking for the email as well puts Apple's private-relay
    // consent step inside the sheet, and the sheet is where sign-up fails.
    request.requestedScopes = [.fullName]
    request.nonce = nonce

    pendingResult = result

    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    self.controller = controller
    controller.performRequests()
  }

  private func finish(_ value: Any?) {
    pendingResult?(value)
    pendingResult = nil
    controller = nil
  }
}

@available(iOS 13.0, *)
extension AppleSignInBridge: ASAuthorizationControllerDelegate {
  func authorizationController(
    controller _: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard
      let credential = authorization.credential as? ASAuthorizationAppleIDCredential
    else {
      finish(
        FlutterError(
          code: "unexpected-credential",
          message: "Apple returned a credential of type "
            + String(describing: type(of: authorization.credential)),
          details: nil
        )
      )
      return
    }

    let identityToken = credential.identityToken.flatMap {
      String(data: $0, encoding: .utf8)
    }
    let authorizationCode = credential.authorizationCode.flatMap {
      String(data: $0, encoding: .utf8)
    }

    finish([
      "userIdentifier": credential.user,
      "identityToken": identityToken as Any,
      "authorizationCode": authorizationCode as Any,
      "givenName": credential.fullName?.givenName as Any,
      "familyName": credential.fullName?.familyName as Any,
      "email": credential.email as Any,
    ])
  }

  func authorizationController(
    controller _: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    let nsError = error as NSError
    finish(
      FlutterError(
        code: "authorization-error",
        message: nsError.localizedDescription,
        details: Self.describe(nsError)
      )
    )
  }

  /// Flattens an NSError and every error nested under it into something the
  /// Flutter method channel can carry. The chain is what matters: Apple's
  /// AuthenticationServices error is a thin wrapper, and the real reason for a
  /// refusal sits in the AKAuthenticationError underneath it.
  private static func describe(_ error: NSError, depth: Int = 0) -> [String: Any] {
    var described: [String: Any] = [
      "domain": error.domain,
      "code": error.code,
      "localizedDescription": error.localizedDescription,
    ]

    if let failureReason = error.localizedFailureReason {
      described["failureReason"] = failureReason
    }

    // userInfo holds arbitrary objects; keep a printable form of each entry so
    // nothing Apple put there is lost, without risking an unencodable value.
    var info: [String: String] = [:]
    for (key, value) in error.userInfo where key != NSUnderlyingErrorKey {
      info[key] = String(describing: value)
    }
    if !info.isEmpty {
      described["userInfo"] = info
    }

    // Guard the recursion: these chains are short, but they are Apple's, not
    // ours, and a cycle here would hang the sign-in.
    if depth < 4,
      let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError
    {
      described["underlying"] = describe(underlying, depth: depth + 1)
    }

    return described
  }
}

@available(iOS 13.0, *)
extension AppleSignInBridge: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes
    let windowScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    if let window = (windowScene as? UIWindowScene)?.windows.first(where: \.isKeyWindow) {
      return window
    }
    return UIApplication.shared.windows.first ?? UIWindow()
  }
}

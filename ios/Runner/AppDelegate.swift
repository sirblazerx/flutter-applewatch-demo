import UIKit
import Flutter
import WatchConnectivity

// Make FlutterError conform to Swift Error
extension FlutterError: Error {}

// MARK: - Swift class that receives method calls from Flutter (Host API)
private class WatchCounterHostAPIImpl: WatchCounterHostAPI {
    let session: WCSession

    init(session: WCSession) {
        self.session = session
    }

    func increment() throws {
        print("📲 increment() called from Flutter")
        session.sendMessage(["method": "increment"], replyHandler: nil, errorHandler: { error in
            print("❌ Failed to send increment to Watch: \(error.localizedDescription)")
        })
    }

    func decrement() throws {
        print("📲 decrement() called from Flutter")
        session.sendMessage(["method": "decrement"], replyHandler: nil, errorHandler: { error in
            print("❌ Failed to send decrement to Watch: \(error.localizedDescription)")
        })
    }

    func setCounter(counter: Int64) throws {
        print("📲 setCounter(\(counter)) called from Flutter")
        session.sendMessage(["method": "setCount", "data": counter], replyHandler: nil, errorHandler: { error in
            print("❌ Failed to send setCounter to Watch: \(error.localizedDescription)")
        })
    }
}

// MARK: - AppDelegate
@main
@objc class AppDelegate: FlutterAppDelegate {
    var session: WCSession?
    var flutterWatchAPI: WatchCounterFlutterAPI?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()

            if let controller = window?.rootViewController as? FlutterViewController {
                let api = WatchCounterHostAPIImpl(session: session!)
                WatchCounterHostAPISetup.setUp(binaryMessenger: controller.binaryMessenger, api: api)

                flutterWatchAPI = WatchCounterFlutterAPI(binaryMessenger: controller.binaryMessenger)
                print("✅ WatchCounterHostAPI is registered")
            } else {
                print("❌ FlutterViewController not found — check window initialization")
            }
        } else {
            print("❌ WCSession is not supported on this device")
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}

// MARK: - WCSessionDelegate (receive from watchOS)
extension AppDelegate: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("🟢 WCSession activated with state: \(activationState.rawValue)")
        if let error = error {
            print("❌ WCSession activation error: \(error.localizedDescription)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ WCSession did become inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ WCSession did deactivate")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task {
            guard let method = message["method"] as? String else {
                print("❌ Invalid message from watch: \(message)")
                return
            }

            switch method {
            case "increment":
                flutterWatchAPI?.increment() { result in
                    switch result {
                    case .success:
                        print("✅ Increment sent to Flutter successfully")
                    case .failure(let error):
                        print("❌ Increment to Flutter failed: \(error.localizedDescription)")
                    }
                }

            case "decrement":
                flutterWatchAPI?.decrement() { result in
                    switch result {
                    case .success:
                        print("✅ Decrement sent to Flutter successfully")
                    case .failure(let error):
                        print("❌ Decrement to Flutter failed: \(error.localizedDescription)")
                    }
                }

            default:
                print("❌ Unknown method received: \(method)")
            }
        }
    }
}

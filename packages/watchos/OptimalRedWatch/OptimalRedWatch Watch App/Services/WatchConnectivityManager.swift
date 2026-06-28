import Combine
import WatchConnectivity
import SwiftUI
import HealthKit

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
  @Published var isConnected = false

  weak var workoutManager: WorkoutManager?

  override init() {
    super.init()
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
  }

  func startWatchConnectivity() {
    DispatchQueue.main.async {
      self.isConnected = WCSession.default.isReachable
    }
  }

  // MARK: - WCSessionDelegate

  func session(
    _ session: WCSession,
    activationDidCompleteWith state: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async {
      self.isConnected = state == .activated
    }
    if let error { print("WCSession error: \(error.localizedDescription)") }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    guard let command = message["command"] as? String else { return }
    DispatchQueue.main.async {
      switch command {
      case "startHike":
        self.workoutManager?.startWorkout(type: .hiking)
      case "startWalk":
        self.workoutManager?.startWorkout(type: .walking)
      case "stopWorkout":
        self.workoutManager?.endWorkout()
      default:
        break
      }
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    self.session(session, didReceiveMessage: message)
    replyHandler(["ack": true])
  }
}

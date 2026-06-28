import WatchConnectivity
import SwiftUI

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
  @Published var isConnected = false
  private var wcSession: WCSession?

  override init() {
    super.init()
    if WCSession.isSupported() {
      wcSession = WCSession.default
      wcSession?.delegate = self
      wcSession?.activate()
    }
  }

  func startWatchConnectivity() {
    DispatchQueue.main.async {
      self.isConnected = self.wcSession?.isReachable ?? false
    }
  }

  func sendHealthMetrics(heartRate: Double, distance: Double, elevation: Double, calories: Double) {
    guard let session = wcSession, session.isReachable else {
      print("Watch Connectivity: iPhone not reachable")
      return
    }

    let data: [String: Any] = [
      "heartRate": heartRate,
      "distance": distance,
      "elevation": elevation,
      "calories": calories,
      "timestamp": Date().timeIntervalSince1970,
    ]

    session.sendMessage(data, replyHandler: { response in
      print("iPhone received metrics: \(response)")
    }) { error in
      print("Error sending metrics: \(error.localizedDescription)")
    }
  }

  func session(
    _: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async {
      self.isConnected = activationState == .activated
    }
    if let error = error {
      print("WCSession activation error: \(error.localizedDescription)")
    }
  }

  func sessionDidBecomeInactive(_: WCSession) {
    DispatchQueue.main.async {
      self.isConnected = false
    }
  }

  func sessionDidDeactivate(_: WCSession) {
    DispatchQueue.main.async {
      self.isConnected = false
    }
  }
}

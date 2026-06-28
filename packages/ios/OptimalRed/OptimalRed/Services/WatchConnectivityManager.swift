import WatchConnectivity
import SwiftUI
import SwiftData
import Combine

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
  @Published var isConnected = false
  @Published var lastReceivedMetrics: [String: Double] = [:]

  private var modelContext: ModelContext?
  weak var recordingManager: WorkoutRecordingManager?

  override init() {
    super.init()
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
  }

  func setModelContext(_ context: ModelContext) {
    modelContext = context
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
    DispatchQueue.main.async { self.isConnected = state == .activated }
    if let error { print("WCSession error: \(error.localizedDescription)") }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {
    DispatchQueue.main.async { self.isConnected = false }
  }

  func sessionDidDeactivate(_ session: WCSession) {
    DispatchQueue.main.async { self.isConnected = false }
    WCSession.default.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    // Live workout update from Watch
    if message["isRecording"] as? Bool == true || message["workoutEnded"] as? Bool == true {
      recordingManager?.handleLiveUpdate(message)
      return
    }
    // Regular metric sync — store to SwiftData
    DispatchQueue.main.async {
      self.lastReceivedMetrics = message.compactMapValues { $0 as? Double }
      if let context = self.modelContext {
        self.storeMetrics(from: message, context: context)
      }
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    self.session(session, didReceiveMessage: message)
    replyHandler(["ack": true])
  }

  // MARK: - Persist to SwiftData

  private func storeMetrics(from message: [String: Any], context: ModelContext) {
    let ts = message["timestamp"] as? Double ?? Date().timeIntervalSince1970
    let date = Date(timeIntervalSince1970: ts)

    let pairs: [(String, Double?, String)] = [
      ("heart_rate", message["heartRate"] as? Double, "bpm"),
      ("distance",   message["distance"]  as? Double, "km"),
      ("elevation",  message["elevation"] as? Double, "m"),
      ("calories",   message["calories"]  as? Double, "kcal"),
    ]
    for (type, value, unit) in pairs {
      guard let value else { continue }
      context.insert(StoredHealthMetric(type: type, value: value, unit: unit, recordedAt: date, source: "watchos"))
    }
    try? context.save()
  }
}

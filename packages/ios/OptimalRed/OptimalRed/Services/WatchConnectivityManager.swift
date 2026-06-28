import WatchConnectivity
import SwiftUI
import SwiftData
import Combine

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
  @Published var isConnected = false
  @Published var lastReceivedMetrics: [String: Double] = [:]
  private var wcSession: WCSession?
  private var modelContext: ModelContext?

  override init() {
    super.init()
    if WCSession.isSupported() {
      wcSession = WCSession.default
      wcSession?.delegate = self
      wcSession?.activate()
    }
  }

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  func startWatchConnectivity() {
    DispatchQueue.main.async {
      self.isConnected = self.wcSession?.isReachable ?? false
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

  func session(_: WCSession, didReceiveMessage message: [String: Any]) {
    DispatchQueue.main.async {
      print("Received from Watch: \(message)")
      self.lastReceivedMetrics = message as? [String: Double] ?? [:]

      if let context = self.modelContext {
        self.storeMetrics(from: message, context: context)
      }
    }
  }

  private func storeMetrics(from message: [String: Any], context: ModelContext) {
    let timestamp = message["timestamp"] as? Double ?? Date().timeIntervalSince1970

    if let hr = message["heartRate"] as? Double {
      let metric = StoredHealthMetric(
        type: "heart_rate",
        value: hr,
        unit: "bpm",
        recordedAt: Date(timeIntervalSince1970: timestamp),
        source: "watchos"
      )
      context.insert(metric)
    }

    if let distance = message["distance"] as? Double {
      let metric = StoredHealthMetric(
        type: "distance",
        value: distance,
        unit: "km",
        recordedAt: Date(timeIntervalSince1970: timestamp),
        source: "watchos"
      )
      context.insert(metric)
    }

    if let elevation = message["elevation"] as? Double {
      let metric = StoredHealthMetric(
        type: "elevation",
        value: elevation,
        unit: "m",
        recordedAt: Date(timeIntervalSince1970: timestamp),
        source: "watchos"
      )
      context.insert(metric)
    }

    if let calories = message["calories"] as? Double {
      let metric = StoredHealthMetric(
        type: "calories",
        value: calories,
        unit: "kcal",
        recordedAt: Date(timeIntervalSince1970: timestamp),
        source: "watchos"
      )
      context.insert(metric)
    }

    do {
      try context.save()
      print("Metrics stored successfully")
    } catch {
      print("Error saving metrics: \(error.localizedDescription)")
    }
  }
}

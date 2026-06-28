import Foundation
import WatchConnectivity

class WorkoutRecordingManager: ObservableObject {
  @Published var isRecording = false
  @Published var currentType: WorkoutType = .hike
  @Published var liveHeartRate: Double = 0
  @Published var liveDistance: Double = 0
  @Published var liveCalories: Double = 0
  @Published var elapsedTime: TimeInterval = 0

  enum WorkoutType { case hike, walk }

  func startHike() {
    currentType = .hike
    isRecording = true
    liveHeartRate = 0; liveDistance = 0; liveCalories = 0; elapsedTime = 0
    send(["command": "startHike"])
  }

  func startWalk() {
    currentType = .walk
    isRecording = true
    liveHeartRate = 0; liveDistance = 0; liveCalories = 0; elapsedTime = 0
    send(["command": "startWalk"])
  }

  func stopRecording() {
    send(["command": "stopWorkout"])
    isRecording = false
  }

  func handleLiveUpdate(_ message: [String: Any]) {
    if message["workoutEnded"] as? Bool == true {
      DispatchQueue.main.async { self.isRecording = false }
      return
    }
    DispatchQueue.main.async {
      if let v = message["heartRate"] as? Double  { self.liveHeartRate = v }
      if let v = message["distance"] as? Double   { self.liveDistance  = v }
      if let v = message["calories"] as? Double   { self.liveCalories  = v }
      if let v = message["elapsedTime"] as? Double { self.elapsedTime  = v }
    }
  }

  private func send(_ message: [String: Any]) {
    guard WCSession.default.isReachable else {
      print("WorkoutRecordingManager: Watch not reachable")
      return
    }
    WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: { error in
      print("WorkoutRecordingManager send error: \(error.localizedDescription)")
    })
  }
}

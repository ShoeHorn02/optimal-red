import HealthKit
import WatchConnectivity
import SwiftUI

class WorkoutManager: NSObject, ObservableObject {
  @Published var isRecording = false
  @Published var elapsedTime: TimeInterval = 0
  @Published var heartRate: Double = 0
  @Published var distance: Double = 0
  @Published var calories: Double = 0
  @Published var workoutType: HKWorkoutActivityType = .hiking

  private let healthStore = HKHealthStore()
  private var session: HKWorkoutSession?
  private var builder: HKLiveWorkoutBuilder?
  private var elapsedTimer: Timer?
  private var broadcastTimer: Timer?

  // MARK: - Authorization

  func requestAuthorization() {
    guard HKHealthStore.isHealthDataAvailable() else { return }

    let share: Set<HKSampleType> = [
      HKObjectType.workoutType(),
      HKQuantityType(.heartRate),
      HKQuantityType(.distanceWalkingRunning),
      HKQuantityType(.activeEnergyBurned),
      HKQuantityType(.flightsClimbed),
    ]
    let read: Set<HKObjectType> = [
      HKObjectType.workoutType(),
      HKQuantityType(.heartRate),
      HKQuantityType(.distanceWalkingRunning),
      HKQuantityType(.activeEnergyBurned),
      HKQuantityType(.flightsClimbed),
    ]

    healthStore.requestAuthorization(toShare: share, read: read) { _, error in
      if let error { print("WorkoutManager auth error: \(error.localizedDescription)") }
    }
  }

  // MARK: - Start / Stop

  func startWorkout(type: HKWorkoutActivityType) {
    workoutType = type

    let config = HKWorkoutConfiguration()
    config.activityType = type
    config.locationType = .outdoor

    do {
      session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
      builder = session?.associatedWorkoutBuilder()
      builder?.dataSource = HKLiveWorkoutDataSource(
        healthStore: healthStore,
        workoutConfiguration: config
      )
      session?.delegate = self
      builder?.delegate = self

      let start = Date()
      session?.startActivity(with: start)
      builder?.beginCollection(withStart: start) { _, _ in }
    } catch {
      print("WorkoutManager: failed to start session — \(error)")
    }
  }

  func endWorkout() {
    session?.end()
  }

  // MARK: - Live metric update

  private func updateFromStatistics(_ stats: HKStatistics) {
    switch stats.quantityType {
    case HKQuantityType(.heartRate):
      heartRate = stats.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? heartRate
    case HKQuantityType(.distanceWalkingRunning):
      distance = (stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0) / 1000
    case HKQuantityType(.activeEnergyBurned):
      calories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? calories
    default:
      break
    }
  }

  // MARK: - Broadcast to iPhone

  private func startTimers(from startDate: Date) {
    elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.elapsedTime = Date().timeIntervalSince(startDate)
    }
    broadcastTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
      self?.broadcastToPhone()
    }
  }

  private func broadcastToPhone() {
    guard WCSession.default.isReachable else { return }
    WCSession.default.sendMessage([
      "heartRate": heartRate,
      "distance": distance,
      "calories": calories,
      "elapsedTime": elapsedTime,
      "isRecording": true,
    ], replyHandler: nil, errorHandler: nil)
  }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
  func workoutSession(
    _ workoutSession: HKWorkoutSession,
    didChangeTo toState: HKWorkoutSessionState,
    from fromState: HKWorkoutSessionState,
    date: Date
  ) {
    DispatchQueue.main.async {
      switch toState {
      case .running:
        self.isRecording = true
        self.startTimers(from: date)
      case .ended:
        self.isRecording = false
        self.elapsedTimer?.invalidate()
        self.broadcastTimer?.invalidate()
        self.builder?.endCollection(withEnd: date) { _, _ in
          self.builder?.finishWorkout { _, _ in
            if WCSession.default.isReachable {
              WCSession.default.sendMessage(["workoutEnded": true], replyHandler: nil, errorHandler: nil)
            }
          }
        }
      default:
        break
      }
    }
  }

  func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    print("WorkoutSession error: \(error.localizedDescription)")
  }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
  func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
    for type in collectedTypes {
      guard let quantityType = type as? HKQuantityType,
            let stats = workoutBuilder.statistics(for: quantityType) else { continue }
      DispatchQueue.main.async { self.updateFromStatistics(stats) }
    }
  }

  func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

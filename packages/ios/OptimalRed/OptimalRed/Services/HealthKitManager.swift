import HealthKit
import SwiftUI
import Combine
import CoreLocation

class HealthKitManager: NSObject, ObservableObject {
  // MARK: - Daily metrics
  @Published var heartRate: Double = 0
  @Published var distance: Double = 0
  @Published var elevation: Double = 0
  @Published var calories: Double = 0
  @Published var isAuthorized = false

  // MARK: - Hike map
  @Published var recentWorkouts: [HKWorkout] = []
  @Published var selectedWorkout: HKWorkout?
  @Published var routeCoordinates: [CLLocationCoordinate2D] = []
  @Published var routeElevationGain: Double = 0
  @Published var isLoadingRoute = false

  private let healthStore = HKHealthStore()

  // MARK: - Authorization

  func requestAuthorization() {
    guard HKHealthStore.isHealthDataAvailable() else { return }

    let typesToRead: Set<HKObjectType> = [
      HKQuantityType.quantityType(forIdentifier: .heartRate)!,
      HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
      HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!,
      HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
      HKObjectType.workoutType(),
      HKSeriesType.workoutRoute(),
    ]

    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
      DispatchQueue.main.async {
        self.isAuthorized = success
        if let error { print("HealthKit auth error: \(error.localizedDescription)") }
      }
    }
  }

  // MARK: - Daily metrics

  func startHealthKitUpdates() {
    fetchHeartRate()
    fetchDailyDistance()
    fetchDailyElevation()
    fetchDailyCalories()
  }

  private func fetchHeartRate() {
    guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: type,
      predicate: HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: Date()),
      limit: 1,
      sortDescriptors: [sort]
    ) { _, samples, _ in
      DispatchQueue.main.async {
        if let sample = samples?.first as? HKQuantitySample {
          self.heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        }
      }
    }
    healthStore.execute(query)
  }

  private func fetchDailyDistance() {
    guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }
    let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: todayPredicate(), options: .cumulativeSum) { _, result, _ in
      DispatchQueue.main.async {
        if let sum = result?.sumQuantity() {
          self.distance = sum.doubleValue(for: .meter()) / 1000
        }
      }
    }
    healthStore.execute(query)
  }

  private func fetchDailyElevation() {
    guard let type = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else { return }
    let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: todayPredicate(), options: .cumulativeSum) { _, result, _ in
      DispatchQueue.main.async {
        if let sum = result?.sumQuantity() {
          self.elevation = sum.doubleValue(for: .count()) * 3.05
        }
      }
    }
    healthStore.execute(query)
  }

  private func fetchDailyCalories() {
    guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
    let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: todayPredicate(), options: .cumulativeSum) { _, result, _ in
      DispatchQueue.main.async {
        if let sum = result?.sumQuantity() {
          self.calories = sum.doubleValue(for: HKUnit(from: "Cal"))
        }
      }
    }
    healthStore.execute(query)
  }

  // MARK: - Hike workouts

  func fetchRecentWorkouts() {
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600)
    let datePredicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: Date())

    let activityPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
      HKQuery.predicateForWorkouts(with: .hiking),
      HKQuery.predicateForWorkouts(with: .walking),
      HKQuery.predicateForWorkouts(with: .running),
    ])

    let combined = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, activityPredicate])

    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: combined,
      limit: 10,
      sortDescriptors: [sort]
    ) { [weak self] _, samples, _ in
      let workouts = samples as? [HKWorkout] ?? []
      DispatchQueue.main.async {
        self?.recentWorkouts = workouts
        if let first = workouts.first {
          self?.selectWorkout(first)
        }
      }
    }
    healthStore.execute(query)
  }

  func selectWorkout(_ workout: HKWorkout) {
    selectedWorkout = workout
    routeCoordinates = []
    routeElevationGain = 0
    isLoadingRoute = true
    fetchRouteForWorkout(workout)
  }

  private func fetchRouteForWorkout(_ workout: HKWorkout) {
    let predicate = HKQuery.predicateForObjects(from: workout)
    let query = HKSampleQuery(
      sampleType: HKSeriesType.workoutRoute(),
      predicate: predicate,
      limit: 1,
      sortDescriptors: nil
    ) { [weak self] _, samples, _ in
      guard let route = samples?.first as? HKWorkoutRoute else {
        DispatchQueue.main.async { self?.isLoadingRoute = false }
        return
      }
      self?.fetchLocations(from: route)
    }
    healthStore.execute(query)
  }

  private func fetchLocations(from route: HKWorkoutRoute) {
    var accumulated: [CLLocation] = []
    let query = HKWorkoutRouteQuery(route: route) { [weak self] _, locations, done, _ in
      if let locations { accumulated.append(contentsOf: locations) }
      if done {
        let gain = Self.calculateElevationGain(from: accumulated)
        DispatchQueue.main.async {
          self?.routeCoordinates = accumulated.map(\.coordinate)
          self?.routeElevationGain = gain
          self?.isLoadingRoute = false
        }
      }
    }
    healthStore.execute(query)
  }

  private static func calculateElevationGain(from locations: [CLLocation]) -> Double {
    var gain = 0.0
    for i in 1..<locations.count {
      let delta = locations[i].altitude - locations[i - 1].altitude
      if delta > 0 { gain += delta }
    }
    return gain
  }

  // MARK: - Helpers

  private func todayPredicate() -> NSPredicate {
    HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
  }
}

import HealthKit
import SwiftUI
import Combine
import CoreLocation

class HealthKitManager: NSObject, ObservableObject {
  @Published var heartRate: Double = 0
  @Published var distance: Double = 0
  @Published var elevation: Double = 0
  @Published var calories: Double = 0
  @Published var isAuthorized = false
  @Published var routeCoordinates: [CLLocationCoordinate2D] = []

  private let healthStore = HKHealthStore()

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

  func startHealthKitUpdates() {
    fetchHeartRate()
    fetchDailyDistance()
    fetchDailyElevation()
    fetchDailyCalories()
    fetchTodayWorkoutRoute()
  }

  // MARK: - Metrics

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
    let predicate = todayPredicate()
    let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
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

  // MARK: - Workout Route

  func fetchTodayWorkoutRoute() {
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: todayPredicate(),
      limit: 1,
      sortDescriptors: [sort]
    ) { [weak self] _, samples, _ in
      guard let workout = samples?.first as? HKWorkout else { return }
      self?.fetchRoute(for: workout)
    }
    healthStore.execute(query)
  }

  private func fetchRoute(for workout: HKWorkout) {
    let predicate = HKQuery.predicateForObjects(from: workout)
    let query = HKSampleQuery(
      sampleType: HKSeriesType.workoutRoute(),
      predicate: predicate,
      limit: 1,
      sortDescriptors: nil
    ) { [weak self] _, samples, _ in
      guard let route = samples?.first as? HKWorkoutRoute else { return }
      self?.fetchLocations(from: route)
    }
    healthStore.execute(query)
  }

  private func fetchLocations(from route: HKWorkoutRoute) {
    var accumulated: [CLLocation] = []
    let query = HKWorkoutRouteQuery(route: route) { [weak self] _, locations, done, _ in
      if let locations { accumulated.append(contentsOf: locations) }
      if done {
        DispatchQueue.main.async {
          self?.routeCoordinates = accumulated.map(\.coordinate)
        }
      }
    }
    healthStore.execute(query)
  }

  // MARK: - Helpers

  private func todayPredicate() -> NSPredicate {
    HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
  }
}

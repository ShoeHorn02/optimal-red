import HealthKit
import SwiftUI
import Combine

class HealthKitManager: NSObject, ObservableObject {
  @Published var heartRate: Double = 0
  @Published var distance: Double = 0
  @Published var elevation: Double = 0
  @Published var calories: Double = 0
  @Published var isAuthorized = false

  private let healthStore = HKHealthStore()

  func requestAuthorization() {
    guard HKHealthStore.isHealthDataAvailable() else {
      print("HealthKit not available on this device")
      return
    }

    let typesToRead: Set<HKObjectType> = [
      HKQuantityType.quantityType(forIdentifier: .heartRate)!,
      HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
      HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!,
      HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
    ]

    healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
      DispatchQueue.main.async {
        self.isAuthorized = success
        if let error = error {
          print("HealthKit authorization error: \(error.localizedDescription)")
        }
      }
    }
  }

  func startHealthKitUpdates() {
    fetchHeartRate()
    fetchDailyDistance()
    fetchDailyElevation()
    fetchDailyCalories()
  }

  private func fetchHeartRate() {
    guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
      return
    }

    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: heartRateType,
      predicate: HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-3600), end: Date()),
      limit: 1,
      sortDescriptors: [sortDescriptor]
    ) { _, samples, _ in
      DispatchQueue.main.async {
        if let sample = samples?.first as? HKQuantitySample {
          let unit = HKUnit(from: "count/min")
          self.heartRate = sample.quantity.doubleValue(for: unit)
        }
      }
    }

    healthStore.execute(query)
  }

  private func fetchDailyDistance() {
    guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
      return
    }

    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: Date())
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())

    let query = HKStatisticsQuery(
      quantityType: distanceType,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum
    ) { _, result, _ in
      DispatchQueue.main.async {
        if let sum = result?.sumQuantity() {
          let distance = sum.doubleValue(for: HKUnit.meter()) / 1000
          self.distance = distance
        }
      }
    }

    healthStore.execute(query)
  }

  private func fetchDailyElevation() {
    guard let elevationType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else {
      return
    }

    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: Date())
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())

    let query = HKStatisticsQuery(
      quantityType: elevationType,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum
    ) { _, result, _ in
      DispatchQueue.main.async {
        if let sum = result?.sumQuantity() {
          let flights = sum.doubleValue(for: HKUnit.count())
          self.elevation = flights * 3.05
        }
      }
    }

    healthStore.execute(query)
  }

  private func fetchDailyCalories() {
    guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
      return
    }

    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: Date())
    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())

    let query = HKStatisticsQuery(
      quantityType: caloriesType,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum
    ) { _, result, _ in
      DispatchQueue.main.async {
        if let sum = result?.sumQuantity() {
          let calories = sum.doubleValue(for: HKUnit(from: "Cal"))
          self.calories = calories
        }
      }
    }

    healthStore.execute(query)
  }
}

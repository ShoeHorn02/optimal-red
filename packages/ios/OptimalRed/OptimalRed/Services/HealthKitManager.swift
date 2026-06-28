import HealthKit
import SwiftUI
import Combine
import CoreLocation

struct KmSplit: Identifiable {
  let id = UUID()
  let number: Int
  let paceSeconds: TimeInterval  // seconds per km

  var paceString: String {
    let m = Int(paceSeconds) / 60
    let s = Int(paceSeconds) % 60
    return String(format: "%d:%02d /km", m, s)
  }
}

class HealthKitManager: NSObject, ObservableObject {
  // MARK: - Daily metrics
  @Published var heartRate: Double = 0
  @Published var distance: Double = 0
  @Published var elevation: Double = 0
  @Published var calories: Double = 0
  @Published var isAuthorized = false

  // MARK: - Workout history
  @Published var recentWorkouts: [HKWorkout] = []
  @Published var selectedWorkout: HKWorkout?
  @Published var isFetchingWorkouts = false
  @Published var hasMoreWorkouts = true

  // MARK: - Selected workout route + stats
  @Published var routeCoordinates: [CLLocationCoordinate2D] = []
  @Published var elevationProfile: [Double] = []   // altitude in metres, sampled
  @Published var kmSplits: [KmSplit] = []
  @Published var routeElevationGain: Double = 0
  @Published var isLoadingRoute = false

  // MARK: - Live observation (any active workout — Fitness app, our app, etc.)
  @Published var isLiveSessionActive = false
  @Published var liveHeartRate: Double = 0
  @Published var liveDistance: Double = 0
  @Published var liveCalories: Double = 0

  private var observerQueries: [HKObserverQuery] = []
  private var workoutPageCursor: Date? = nil
  private let workoutPageSize = 20

  private let healthStore = HKHealthStore()

  // MARK: - Authorization

  func requestAuthorization() {
    guard HKHealthStore.isHealthDataAvailable() else { return }

    let typesToRead: Set<HKObjectType> = [
      HKQuantityType.quantityType(forIdentifier: .heartRate)!,
      HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
      HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
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

  // MARK: - Hike workouts (paginated)

  func fetchRecentWorkouts() {
    workoutPageCursor = nil
    recentWorkouts = []
    hasMoreWorkouts = true
    fetchNextWorkoutPage()
  }

  func fetchMoreWorkouts() {
    guard hasMoreWorkouts, !isFetchingWorkouts else { return }
    fetchNextWorkoutPage()
  }

  private func fetchNextWorkoutPage() {
    isFetchingWorkouts = true
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

    let predicate: NSPredicate
    if let cursor = workoutPageCursor {
      predicate = HKQuery.predicateForSamples(withStart: .distantPast, end: cursor)
    } else {
      predicate = HKQuery.predicateForSamples(withStart: .distantPast, end: Date())
    }

    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: predicate,
      limit: workoutPageSize,
      sortDescriptors: [sort]
    ) { [weak self] _, samples, _ in
      guard let self else { return }
      let workouts = samples as? [HKWorkout] ?? []
      DispatchQueue.main.async {
        let isFirst = self.recentWorkouts.isEmpty
        self.recentWorkouts.append(contentsOf: workouts)
        self.isFetchingWorkouts = false
        self.hasMoreWorkouts = workouts.count == self.workoutPageSize
        self.workoutPageCursor = workouts.last?.startDate
        if isFirst {
          // Auto-select first GPS-capable workout so the map has something to show
          let gpsTypes: Set<HKWorkoutActivityType> = [
            .hiking, .walking, .running, .cycling,
            .crossCountrySkiing, .downhillSkiing, .snowboarding, .skatingSports,
            .paddleSports, .rowing, .surfingSports, .waterFitness
          ]
          if let first = workouts.first(where: { gpsTypes.contains($0.workoutActivityType) }) {
            self.selectWorkout(first)
          } else if let first = workouts.first {
            self.selectWorkout(first)
          }
        }
      }
    }
    healthStore.execute(query)
  }

  // MARK: - Live observation (works with Fitness app, our app, or any HealthKit source)

  func startLiveObservation() {
    stopLiveObservation()
    let types: [(HKQuantityTypeIdentifier, (Double) -> Void)] = [
      (.heartRate,              { [weak self] v in self?.liveHeartRate = v }),
      (.distanceWalkingRunning, { [weak self] v in self?.liveDistance  = v / 1000 }),
      (.activeEnergyBurned,     { [weak self] v in self?.liveCalories  = v }),
    ]
    for (id, handler) in types {
      guard let type = HKQuantityType.quantityType(forIdentifier: id) else { continue }
      let observer = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
        self?.fetchLatestSample(type: type, unit: Self.unit(for: id), handler: handler)
        completion()
      }
      healthStore.execute(observer)
      healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
      observerQueries.append(observer)
    }
  }

  func stopLiveObservation() {
    observerQueries.forEach { healthStore.stop($0) }
    observerQueries = []
    isLiveSessionActive = false
  }

  private func fetchLatestSample(type: HKQuantityType, unit: HKUnit, handler: @escaping (Double) -> Void) {
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
    let since = Date().addingTimeInterval(-60)
    let predicate = HKQuery.predicateForSamples(withStart: since, end: nil)
    let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { [weak self] _, samples, _ in
      guard let sample = samples?.first as? HKQuantitySample else { return }
      let value = sample.quantity.doubleValue(for: unit)
      DispatchQueue.main.async {
        handler(value)
        self?.isLiveSessionActive = true
        self?.scheduleLiveTimeout()
      }
    }
    healthStore.execute(query)
  }

  private var liveTimeoutTask: Task<Void, Never>?
  private func scheduleLiveTimeout() {
    liveTimeoutTask?.cancel()
    liveTimeoutTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 30_000_000_000)
      await MainActor.run { self?.isLiveSessionActive = false }
    }
  }

  private static func unit(for id: HKQuantityTypeIdentifier) -> HKUnit {
    switch id {
    case .heartRate:              return HKUnit(from: "count/min")
    case .activeEnergyBurned:    return .kilocalorie()
    default:                      return .meter()
    }
  }

  func selectWorkout(_ workout: HKWorkout) {
    selectedWorkout = workout
    routeCoordinates = []
    elevationProfile = []
    kmSplits = []
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
        let gain   = Self.calculateElevationGain(from: accumulated)
        let profile = Self.sampleElevationProfile(from: accumulated, maxPoints: 200)
        let splits  = Self.calculateKmSplits(from: accumulated)
        DispatchQueue.main.async {
          self?.routeCoordinates  = accumulated.map(\.coordinate)
          self?.elevationProfile  = profile
          self?.kmSplits          = splits
          self?.routeElevationGain = gain
          self?.isLoadingRoute    = false
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

  private static func sampleElevationProfile(from locations: [CLLocation], maxPoints: Int) -> [Double] {
    guard !locations.isEmpty else { return [] }
    let step = max(1, locations.count / maxPoints)
    return stride(from: 0, to: locations.count, by: step).map { locations[$0].altitude }
  }

  private static func calculateKmSplits(from locations: [CLLocation]) -> [KmSplit] {
    guard locations.count > 1 else { return [] }
    var splits: [KmSplit] = []
    var kmStart = locations[0]
    var kmDist  = 0.0
    var kmNum   = 1

    for i in 1..<locations.count {
      let d = locations[i].distance(from: locations[i - 1])
      kmDist += d
      if kmDist >= 1000 {
        let elapsed = locations[i].timestamp.timeIntervalSince(kmStart.timestamp)
        splits.append(KmSplit(number: kmNum, paceSeconds: elapsed))
        kmStart = locations[i]
        kmDist  = 0
        kmNum  += 1
      }
    }
    return splits
  }

  // MARK: - Helpers

  private func todayPredicate() -> NSPredicate {
    HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: Date()), end: Date())
  }
}

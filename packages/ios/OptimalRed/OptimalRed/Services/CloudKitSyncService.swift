import CloudKit
import HealthKit
import Combine

class CloudKitSyncService: ObservableObject {
  static let shared = CloudKitSyncService()

  @Published var isSyncing = false
  @Published var syncProgress: Double = 0      // 0–1
  @Published var lastSyncDate: Date?
  @Published var accountStatus: CKAccountStatus = .couldNotDetermine
  @Published var syncError: String?

  private let container  = CKContainer(identifier: "iCloud.app.optimalred.ios")
  private var privateDB: CKDatabase { container.privateCloudDatabase }
  private let healthStore = HKHealthStore()
  private let lastSyncKey = "ck_last_sync"
  private let batchSize   = 50

  init() {
    lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    checkAccount()
  }

  func checkAccount() {
    container.accountStatus { [weak self] status, _ in
      DispatchQueue.main.async { self?.accountStatus = status }
    }
  }

  // MARK: - Sync HealthKit → CloudKit

  func sync() {
    guard !isSyncing else { return }
    guard accountStatus == .available else {
      syncError = "iCloud not available — sign in to iCloud in Settings"
      return
    }
    isSyncing = true
    syncError = nil
    syncProgress = 0

    let since = lastSyncDate ?? .distantPast
    fetchHKWorkouts(since: since) { [weak self] workouts in
      guard let self else { return }
      guard !workouts.isEmpty else {
        DispatchQueue.main.async { self.finishSync() }
        return
      }
      self.uploadAll(workouts)
    }
  }

  private func fetchHKWorkouts(since: Date, completion: @escaping ([HKWorkout]) -> Void) {
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
    let pred = HKQuery.predicateForSamples(withStart: since, end: Date())
    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: pred,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: [sort]
    ) { _, samples, _ in
      completion(samples as? [HKWorkout] ?? [])
    }
    healthStore.execute(query)
  }

  private func uploadAll(_ workouts: [HKWorkout]) {
    let records = workouts.map(CKRecord.init(workout:))
    let total   = records.count
    var uploaded = 0

    let batches = stride(from: 0, to: total, by: batchSize).map {
      Array(records[$0..<min($0 + batchSize, total)])
    }

    func next(_ idx: Int) {
      guard idx < batches.count else {
        DispatchQueue.main.async { self.finishSync() }
        return
      }
      let op = CKModifyRecordsOperation(recordsToSave: batches[idx], recordIDsToDelete: nil)
      op.savePolicy = .allKeys
      op.isAtomic   = false
      op.modifyRecordsResultBlock = { _ in
        uploaded += batches[idx].count
        DispatchQueue.main.async {
          self.syncProgress = Double(uploaded) / Double(total)
        }
        next(idx + 1)
      }
      privateDB.add(op)
    }
    next(0)
  }

  private func finishSync() {
    isSyncing    = false
    syncProgress = 1
    lastSyncDate = Date()
    UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
  }
}

// MARK: - CKRecord ↔ HKWorkout

extension CKRecord {
  convenience init(workout: HKWorkout) {
    let id = CKRecord.ID(recordName: workout.uuid.uuidString)
    self.init(recordType: "WorkoutRecord", recordID: id)

    self["activityType"]     = Int64(workout.workoutActivityType.rawValue)
    self["activityName"]     = workout.workoutActivityType.displayName
    self["startDate"]        = workout.startDate
    self["endDate"]          = workout.endDate
    self["duration"]         = workout.duration
    self["distanceMeters"]   = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
    self["activeEnergyKcal"] = workout.statistics(
      for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
    )?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    self["sourceBundleID"]   = workout.sourceRevision.source.bundleIdentifier
    self["sourceName"]       = workout.sourceRevision.source.name
  }
}

extension HKWorkoutActivityType {
  var displayName: String {
    switch self {
    case .hiking:           return "Hike"
    case .walking:          return "Walk"
    case .running:          return "Run"
    case .cycling:          return "Cycle"
    case .swimming:         return "Swim"
    case .traditionalStrengthTraining: return "Strength"
    case .functionalStrengthTraining:  return "Strength"
    case .yoga:             return "Yoga"
    case .dance:            return "Dance"
    case .soccer:           return "Soccer"
    case .tennis:           return "Tennis"
    case .basketball:       return "Basketball"
    case .rowing:           return "Rowing"
    case .elliptical:       return "Elliptical"
    case .stairClimbing:    return "Stair Climb"
    case .crossTraining:    return "Cross Training"
    case .pilates:          return "Pilates"
    case .mindAndBody:      return "Mindfulness"
    default:                return "Workout"
    }
  }
}

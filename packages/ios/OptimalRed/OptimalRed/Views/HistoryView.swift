import SwiftUI
import HealthKit

// MARK: - Accent colours matching the Fitness app aesthetic
private let accentGreen = Color(red: 0.60, green: 0.95, blue: 0.13)
private let iconBg      = Color(red: 0.13, green: 0.22, blue: 0.10)
private let cardBg      = Color(white: 0.12)

struct HistoryView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @State private var selectedWorkout: HKWorkout?
  @State private var typeFilter: HKWorkoutActivityType? = nil

  private var uniqueTypes: [HKWorkoutActivityType] {
    Array(Set(healthKitManager.recentWorkouts.map { $0.workoutActivityType }))
      .sorted { $0.rawValue < $1.rawValue }
  }

  private var filtered: [HKWorkout] {
    guard let t = typeFilter else { return healthKitManager.recentWorkouts }
    return healthKitManager.recentWorkouts.filter { $0.workoutActivityType == t }
  }

  private var grouped: [(String, [HKWorkout])] {
    let fmt = DateFormatter(); fmt.dateFormat = "MMMM yyyy"
    let dict = Dictionary(grouping: filtered) { fmt.string(from: $0.startDate) }
    return dict.sorted {
      (fmt.date(from: $0.key) ?? .distantPast) > (fmt.date(from: $1.key) ?? .distantPast)
    }
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 0) {
        // ── Title row ──────────────────────────────────────────
        HStack(alignment: .center) {
          Text("Sessions")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.white)
          Spacer()
          if healthKitManager.isFetchingWorkouts {
            ProgressView().tint(.white).scaleEffect(0.8)
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)

        // ── Filter picker ────────────────────────────────────────
        HStack {
          Picker("Activity", selection: Binding(
            get: { typeFilter?.rawValue ?? UInt.max },
            set: { typeFilter = $0 == UInt.max ? nil : HKWorkoutActivityType(rawValue: $0) }
          )) {
            Text("All Workouts").tag(UInt.max)
            ForEach(uniqueTypes, id: \.rawValue) { t in
              Text(t.displayName).tag(t.rawValue)
            }
          }
          .pickerStyle(.menu)
          .tint(accentGreen)
          .fontWeight(.semibold)
          Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)

        // ── Content ─────────────────────────────────────────────
        if filtered.isEmpty && !healthKitManager.isFetchingWorkouts {
          Spacer()
          emptyState
          Spacer()
        } else {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
              ForEach(grouped, id: \.0) { month, workouts in
                // Month header
                Text(month)
                  .font(.system(size: 20, weight: .bold))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 16)
                  .padding(.top, 22)
                  .padding(.bottom, 10)

                // Grouped cards
                VStack(spacing: 0) {
                  ForEach(Array(workouts.enumerated()), id: \.element.uuid) { idx, workout in
                    SessionCard(workout: workout, showDivider: idx < workouts.count - 1)
                      .contentShape(Rectangle())
                      .onTapGesture {
                        healthKitManager.selectWorkout(workout)
                        selectedWorkout = workout
                      }
                      .onAppear {
                        if workout.uuid == healthKitManager.recentWorkouts.last?.uuid {
                          healthKitManager.fetchMoreWorkouts()
                        }
                      }
                  }
                }
                .background(cardBg, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
              }

              if healthKitManager.hasMoreWorkouts && !healthKitManager.isFetchingWorkouts {
                ProgressView().tint(.white)
                  .frame(maxWidth: .infinity).padding()
                  .onAppear { healthKitManager.fetchMoreWorkouts() }
              }

              Color.clear.frame(height: 24)
            }
          }
        }
      }
    }
    .preferredColorScheme(.dark)
    .sheet(item: $selectedWorkout) { w in
      WorkoutDetailSheet(workout: w).environmentObject(healthKitManager)
    }
    .onAppear {
      if healthKitManager.recentWorkouts.isEmpty { healthKitManager.fetchRecentWorkouts() }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 14) {
      Image(systemName: "list.bullet.clipboard").font(.system(size: 48)).foregroundStyle(.secondary)
      Text("No workouts yet").font(.headline).foregroundStyle(.white)
      Text("Workouts from Apple Health will appear here.")
        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Session card row

struct SessionCard: View {
  let workout: HKWorkout
  let showDivider: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 14) {
        // Icon circle
        ZStack {
          Circle().fill(iconBg).frame(width: 46, height: 46)
          Image(systemName: activityIcon)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(accentGreen)
        }

        // Name + primary stat
        VStack(alignment: .leading, spacing: 1) {
          Text(workout.workoutActivityType.displayName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)

          HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(primaryValue)
              .font(.system(size: 30, weight: .bold, design: .rounded))
              .foregroundStyle(accentGreen)
            Text(primaryUnit)
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(accentGreen)
              .padding(.leading, 1)
          }
        }

        Spacer()

        // Date
        Text(shortDate)
          .font(.system(size: 13))
          .foregroundStyle(Color(white: 0.45))
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 14)

      if showDivider {
        Rectangle()
          .fill(Color(white: 0.22))
          .frame(height: 0.5)
          .padding(.leading, 74)
      }
    }
  }

  private var primaryValue: String {
    let dist = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
    if dist > 0 { return String(format: "%.2f", dist / 1000) }
    let cal = activeCal
    if cal > 0 { return String(format: "%.0f", cal) }
    let m = Int(workout.duration) / 60
    let h = m / 60
    return h > 0 ? "\(h):\(String(format: "%02d", m % 60))" : "\(m)"
  }

  private var primaryUnit: String {
    let dist = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
    if dist > 0 { return "KM" }
    if activeCal > 0 { return "CAL" }
    return "MIN"
  }

  private var activeCal: Double {
    workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?
      .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
  }

  var activityIcon: String {
    switch workout.workoutActivityType {
    case .hiking:   return "figure.hiking"
    case .running:  return "figure.run"
    case .cycling:  return "figure.outdoor.cycle"
    case .swimming: return "figure.pool.swim"
    case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
    case .yoga:     return "figure.yoga"
    case .dance:    return "figure.dance"
    case .rowing:   return "figure.rowing"
    case .elliptical: return "figure.elliptical"
    case .stairClimbing: return "figure.stair.stepper"
    case .pilates:  return "figure.pilates"
    case .mindAndBody: return "brain.head.profile"
    case .soccer:   return "soccerball"
    case .tennis:   return "tennisball.fill"
    case .basketball: return "basketball.fill"
    default:        return "figure.walk"
    }
  }

  private var shortDate: String {
    let cal = Calendar.current
    if cal.isDateInToday(workout.startDate)     { return "Today" }
    if cal.isDateInYesterday(workout.startDate) { return "Yesterday" }
    let fmt = DateFormatter(); fmt.dateFormat = "M/d/yy"
    return fmt.string(from: workout.startDate)
  }
}

// Make HKWorkout identifiable for .sheet(item:)
extension HKWorkout: @retroactive Identifiable {
  public var id: UUID { uuid }
}

#Preview {
  HistoryView().environmentObject(HealthKitManager())
}

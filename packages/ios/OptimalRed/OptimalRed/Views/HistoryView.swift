import SwiftUI
import HealthKit

struct HistoryView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @State private var selectedWorkout: HKWorkout?

  var body: some View {
    NavigationStack {
      Group {
        if healthKitManager.recentWorkouts.isEmpty && !healthKitManager.isFetchingWorkouts {
          emptyState
        } else {
          workoutList
        }
      }
      .navigationTitle("History")
      .sheet(item: $selectedWorkout) { workout in
        WorkoutDetailSheet(workout: workout)
          .environmentObject(healthKitManager)
      }
      .onAppear {
        if healthKitManager.recentWorkouts.isEmpty {
          healthKitManager.fetchRecentWorkouts()
        }
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          if healthKitManager.isFetchingWorkouts {
            ProgressView().scaleEffect(0.75)
          }
        }
      }
    }
  }

  // MARK: - Workout list

  private var workoutList: some View {
    List {
      ForEach(healthKitManager.recentWorkouts, id: \.uuid) { workout in
        WorkoutRow(workout: workout)
          .contentShape(Rectangle())
          .onTapGesture { selectedWorkout = workout }
          .onAppear {
            if workout.uuid == healthKitManager.recentWorkouts.last?.uuid {
              healthKitManager.fetchMoreWorkouts()
            }
          }
      }

      if healthKitManager.isFetchingWorkouts {
        HStack {
          Spacer()
          ProgressView()
          Spacer()
        }
        .listRowSeparator(.hidden)
      }
    }
    .listStyle(.plain)
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "list.bullet.clipboard")
        .font(.system(size: 52))
        .foregroundStyle(.quaternary)
      Text("No workouts yet")
        .font(.headline)
      Text("Your workouts from Apple Health will appear here.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Workout Row

struct WorkoutRow: View {
  let workout: HKWorkout

  var body: some View {
    HStack(spacing: 14) {
      ZStack {
        RoundedRectangle(cornerRadius: 10)
          .fill(activityColor.opacity(0.15))
          .frame(width: 42, height: 42)
        Image(systemName: activityIcon)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(activityColor)
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(workout.workoutActivityType.displayName)
          .font(.subheadline.weight(.semibold))
        Text(rowDate)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 3) {
        if let dist = distanceKm, dist > 0 {
          Text(String(format: "%.2f km", dist))
            .font(.subheadline.weight(.medium).monospacedDigit())
        }
        Text(formatDuration(workout.duration))
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
    }
    .padding(.vertical, 4)
  }

  private var distanceKm: Double? {
    guard let d = workout.totalDistance?.doubleValue(for: .meter()), d > 0 else { return nil }
    return d / 1000
  }

  private var rowDate: String {
    let cal = Calendar.current
    if cal.isDateInToday(workout.startDate)     { return "Today · \(workout.startDate.formatted(.dateTime.hour().minute()))" }
    if cal.isDateInYesterday(workout.startDate) { return "Yesterday · \(workout.startDate.formatted(.dateTime.hour().minute()))" }
    return workout.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
  }

  private func formatDuration(_ t: TimeInterval) -> String {
    let h = Int(t) / 3600; let m = (Int(t) % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
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

  var activityColor: Color {
    switch workout.workoutActivityType {
    case .hiking:   return .green
    case .running:  return .orange
    case .cycling:  return .blue
    case .swimming: return .cyan
    case .traditionalStrengthTraining, .functionalStrengthTraining: return .purple
    case .yoga:     return .pink
    case .mindAndBody: return .indigo
    case .tennis, .basketball, .soccer: return .yellow
    default:        return .red
    }
  }
}

// Make HKWorkout identifiable for .sheet(item:)
extension HKWorkout: @retroactive Identifiable {
  public var id: UUID { uuid }
}

#Preview {
  HistoryView().environmentObject(HealthKitManager())
}

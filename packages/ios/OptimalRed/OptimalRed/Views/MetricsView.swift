import SwiftUI
import HealthKit

struct MetricsView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager

  private var lastWorkout: HKWorkout? { healthKitManager.recentWorkouts.first }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          if let workout = lastWorkout {
            lastWorkoutHero(workout)
          } else if healthKitManager.isFetchingWorkouts {
            ProgressView("Loading last workout…")
              .frame(maxWidth: .infinity)
              .padding(.top, 60)
          } else {
            noWorkoutState
          }

          todayStats
        }
        .padding()
      }
      .navigationTitle("Activity")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            healthKitManager.startHealthKitUpdates()
            healthKitManager.fetchRecentWorkouts()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
      .onAppear {
        healthKitManager.requestAuthorization()
        healthKitManager.startHealthKitUpdates()
        if healthKitManager.recentWorkouts.isEmpty {
          healthKitManager.fetchRecentWorkouts()
        }
      }
    }
  }

  // MARK: - Last Workout Hero Card

  private func lastWorkoutHero(_ workout: HKWorkout) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        ZStack {
          Circle()
            .fill(activityColor(workout).opacity(0.15))
            .frame(width: 44, height: 44)
          Image(systemName: activityIcon(workout))
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(activityColor(workout))
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(workout.workoutActivityType.displayName)
            .font(.title3.weight(.bold))
          Text(relativeDate(workout.startDate))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text(formatDuration(workout.duration))
          .font(.title3.weight(.semibold).monospacedDigit())
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 12)

      Divider().padding(.horizontal, 16)

      // Stats grid
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
        heroStat(
          value: distanceString(workout),
          unit: "km",
          icon: "figure.walk",
          color: .blue
        )
        heroDivider
        heroStat(
          value: caloriesString(workout),
          unit: "kcal",
          icon: "flame.fill",
          color: .orange
        )
        heroDivider
        heroStat(
          value: avgHRString(workout),
          unit: "BPM",
          icon: "heart.fill",
          color: .red
        )
      }
      .padding(.vertical, 12)
    }
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
  }

  private var heroDivider: some View {
    Rectangle()
      .fill(Color(.separator).opacity(0.5))
      .frame(width: 1, height: 36)
  }

  private func heroStat(value: String, unit: String, icon: String, color: Color) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon).font(.caption).foregroundStyle(color)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(value).font(.subheadline.weight(.bold).monospacedDigit())
        Text(unit).font(.caption2).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Today's quick stats

  private var todayStats: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Today")
        .font(.headline)
        .padding(.horizontal, 2)

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        SmallMetricCard(
          label: "Distance",
          value: String(format: "%.2f", healthKitManager.distance),
          unit: "km", icon: "figure.walk", color: .blue
        )
        SmallMetricCard(
          label: "Elevation",
          value: String(format: "%.0f", healthKitManager.elevation),
          unit: "m", icon: "mountain.2.fill", color: .green
        )
        SmallMetricCard(
          label: "Calories",
          value: String(format: "%.0f", healthKitManager.calories),
          unit: "kcal", icon: "flame.fill", color: .orange
        )
        SmallMetricCard(
          label: "Heart Rate",
          value: healthKitManager.heartRate > 0 ? String(format: "%.0f", healthKitManager.heartRate) : "–",
          unit: "BPM", icon: "heart.fill", color: .red
        )
      }
    }
  }

  // MARK: - Empty state

  private var noWorkoutState: some View {
    VStack(spacing: 12) {
      Image(systemName: "figure.walk.circle")
        .font(.system(size: 48))
        .foregroundStyle(.quaternary)
      Text("No recent workouts")
        .font(.headline)
      Text("Workouts from Apple Health will appear here.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  // MARK: - Helpers

  private func activityIcon(_ workout: HKWorkout) -> String {
    switch workout.workoutActivityType {
    case .hiking:   return "figure.hiking"
    case .running:  return "figure.run"
    case .cycling:  return "figure.outdoor.cycle"
    case .swimming: return "figure.pool.swim"
    case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
    case .yoga:     return "figure.yoga"
    default:        return "figure.walk"
    }
  }

  private func activityColor(_ workout: HKWorkout) -> Color {
    switch workout.workoutActivityType {
    case .hiking:   return .green
    case .running:  return .orange
    case .cycling:  return .blue
    case .swimming: return .cyan
    case .traditionalStrengthTraining, .functionalStrengthTraining: return .purple
    case .yoga:     return .pink
    default:        return .red
    }
  }

  private func distanceString(_ w: HKWorkout) -> String {
    let m = w.totalDistance?.doubleValue(for: .meter()) ?? 0
    return m > 0 ? String(format: "%.2f", m / 1000) : "–"
  }

  private func caloriesString(_ w: HKWorkout) -> String {
    let cal = w.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?
      .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    return cal > 0 ? String(format: "%.0f", cal) : "–"
  }

  private func avgHRString(_ w: HKWorkout) -> String {
    let hr = w.statistics(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)?
      .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
    return hr > 0 ? String(format: "%.0f", hr) : "–"
  }

  private func formatDuration(_ t: TimeInterval) -> String {
    let h = Int(t) / 3600; let m = (Int(t) % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
  }

  private func relativeDate(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date)     { return "Today · \(date.formatted(.dateTime.hour().minute()))" }
    if cal.isDateInYesterday(date) { return "Yesterday · \(date.formatted(.dateTime.hour().minute()))" }
    return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
  }
}

// MARK: - Shared card components (used by MetricsView)

struct SmallMetricCard: View {
  let label: String
  let value: String
  let unit: String
  let icon: String
  let color: Color

  var body: some View {
    RoundedRectangle(cornerRadius: 16)
      .fill(Color(.secondarySystemBackground))
      .frame(height: 110)
      .overlay(
        VStack(alignment: .leading, spacing: 0) {
          Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(color)
          Spacer()
          HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(unit).font(.caption).foregroundStyle(.secondary)
          }
          Text(label).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
      )
  }
}

#Preview {
  MetricsView().environmentObject(HealthKitManager())
}

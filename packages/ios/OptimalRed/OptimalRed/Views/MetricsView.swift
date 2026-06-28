import SwiftUI
import HealthKit
import Combine

struct MetricsView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @State private var pulse = false

  private var lastWorkout: HKWorkout? { healthKitManager.recentWorkouts.first }

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {

            if healthKitManager.isLiveSessionActive {
              liveBanner
            }

            if let w = lastWorkout {
              heroCard(w)
            } else if healthKitManager.isFetchingWorkouts {
              ProgressView("Loading…")
                .frame(maxWidth: .infinity).padding(.top, 60)
            } else {
              emptyState
            }

            todaySection

            if healthKitManager.recentWorkouts.count > 1 {
              recentSection
            }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 40)
        }
      }
      .navigationTitle("Activity")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            healthKitManager.startHealthKitUpdates()
            healthKitManager.fetchRecentWorkouts()
          } label: { Image(systemName: "arrow.clockwise") }
        }
      }
      .toolbarBackground(.black, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .onAppear {
        healthKitManager.requestAuthorization()
        healthKitManager.startHealthKitUpdates()
        healthKitManager.startLiveObservation()
        healthKitManager.pollForLiveActivity()
        if healthKitManager.recentWorkouts.isEmpty { healthKitManager.fetchRecentWorkouts() }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
      }
      // Poll every 60s so we catch the batch HR sync from Apple Watch
      .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
        healthKitManager.pollForLiveActivity()
      }
    }
  }

  // MARK: - Live banner

  private var liveBanner: some View {
    HStack(spacing: 14) {
      Circle()
        .fill(.red)
        .frame(width: 10, height: 10)
        .scaleEffect(pulse ? 1.5 : 1.0)
        .opacity(pulse ? 0.4 : 1.0)

      VStack(alignment: .leading, spacing: 2) {
        Text("LIVE").font(.caption.weight(.black)).foregroundStyle(.red)
        Text("Workout in progress").font(.subheadline).foregroundStyle(.white)
      }

      Spacer()

      if healthKitManager.liveHeartRate > 0 {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
          Text("\(Int(healthKitManager.liveHeartRate))")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.red)
          Text("BPM").font(.caption.weight(.semibold)).foregroundStyle(.red.opacity(0.7))
        }
      }
    }
    .padding(16)
    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.25), lineWidth: 1))
  }

  // MARK: - Hero card

  private func heroCard(_ w: HKWorkout) -> some View {
    VStack(alignment: .leading, spacing: 0) {

      // ── Header row ─────────────────────────────────────────
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(workoutColor(w).opacity(0.18))
            .frame(width: 52, height: 52)
          Image(systemName: workoutIcon(w))
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(workoutColor(w))
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(w.workoutActivityType.displayName)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.white)
          Text(relativeDate(w.startDate))
            .font(.subheadline).foregroundStyle(.secondary)
        }
        Spacer()
        Text(formatDuration(w.duration))
          .font(.system(size: 20, weight: .semibold, design: .rounded))
          .foregroundStyle(Color(white: 0.55))
      }
      .padding(16)

      // ── Primary stat ─────────────────────────────────────
      let distKm = distKm(w)
      let cal    = activeCal(w)

      if distKm > 0 {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(String(format: "%.2f", distKm))
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundStyle(workoutColor(w))
          Text("km")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(workoutColor(w).opacity(0.55))
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
      } else if cal > 0 {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(String(format: "%.0f", cal))
            .font(.system(size: 64, weight: .bold, design: .rounded))
            .foregroundStyle(.orange)
          Text("cal")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.orange.opacity(0.55))
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
      }

      // ── Divider ──────────────────────────────────────────
      Rectangle().fill(Color(white: 0.18)).frame(height: 0.5).padding(.horizontal, 16)

      // ── Secondary stats ──────────────────────────────────
      HStack(spacing: 0) {
        let hr        = avgHR(w)
        let elevGain  = healthKitManager.routeElevationGain

        if cal > 0 {
          miniStat(value: String(format: "%.0f", cal), unit: "CAL", icon: "flame.fill", color: .orange)
        }
        if cal > 0 && hr > 0 { vLine }
        if hr > 0 {
          miniStat(value: String(format: "%.0f", hr), unit: "BPM", icon: "heart.fill", color: .red)
        }
        if elevGain > 1 {
          if cal > 0 || hr > 0 { vLine }
          miniStat(value: String(format: "%.0f", elevGain), unit: "m ↑", icon: "mountain.2.fill", color: Color(red: 0.60, green: 0.95, blue: 0.13))
        }
      }
      .padding(.vertical, 14)
    }
    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 20))
  }

  private var vLine: some View {
    Rectangle().fill(Color(white: 0.22)).frame(width: 0.5, height: 36)
  }

  private func miniStat(value: String, unit: String, icon: String, color: Color) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon).font(.caption2).foregroundStyle(color)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(value).font(.system(size: 17, weight: .bold, design: .rounded))
        Text(unit).font(.caption2).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Today

  private var todaySection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Today")
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(.white)

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        SmallMetricCard(label: "Distance",
                        value: String(format: "%.1f", healthKitManager.distance),
                        unit: "km", icon: "figure.walk", color: .blue)
        SmallMetricCard(label: "Heart Rate",
                        value: healthKitManager.heartRate > 0 ? String(format: "%.0f", healthKitManager.heartRate) : "–",
                        unit: "BPM", icon: "heart.fill", color: .red)
        SmallMetricCard(label: "Calories",
                        value: String(format: "%.0f", healthKitManager.calories),
                        unit: "cal", icon: "flame.fill", color: .orange)
        SmallMetricCard(label: "Elevation",
                        value: String(format: "%.0f", healthKitManager.elevation),
                        unit: "m", icon: "mountain.2.fill", color: Color(red: 0.60, green: 0.95, blue: 0.13))
      }
    }
  }

  // MARK: - Recent

  private var recentSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Recent")
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(.white)

      let items = Array(healthKitManager.recentWorkouts.dropFirst().prefix(4))
      VStack(spacing: 0) {
        ForEach(Array(items.enumerated()), id: \.element.uuid) { i, w in
          recentRow(w, showDivider: i < items.count - 1)
        }
      }
      .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 16))
    }
  }

  private func recentRow(_ w: HKWorkout, showDivider: Bool) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: workoutIcon(w))
          .font(.system(size: 18, weight: .medium))
          .foregroundStyle(workoutColor(w))
          .frame(width: 28)

        VStack(alignment: .leading, spacing: 2) {
          Text(w.workoutActivityType.displayName)
            .font(.subheadline.weight(.medium)).foregroundStyle(.white)
          Text(shortDate(w.startDate))
            .font(.caption).foregroundStyle(.secondary)
        }

        Spacer()

        let km = distKm(w)
        if km > 0.1 {
          Text(String(format: "%.1f km", km))
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(workoutColor(w))
        } else {
          Text(formatDuration(w.duration))
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
      .padding(.horizontal, 16).padding(.vertical, 14)

      if showDivider {
        Rectangle().fill(Color(white: 0.2)).frame(height: 0.5).padding(.leading, 56)
      }
    }
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "figure.walk.circle")
        .font(.system(size: 52)).foregroundStyle(.quaternary)
      Text("No recent workouts").font(.headline)
      Text("Workouts from Apple Health will appear here.")
        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 40)
  }

  // MARK: - Helpers

  private func distKm(_ w: HKWorkout) -> Double {
    (w.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000
  }

  private func activeCal(_ w: HKWorkout) -> Double {
    w.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?
      .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
  }

  private func avgHR(_ w: HKWorkout) -> Double {
    w.statistics(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)?
      .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
  }

  func workoutIcon(_ w: HKWorkout) -> String {
    switch w.workoutActivityType {
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
    default:        return "figure.walk"
    }
  }

  func workoutColor(_ w: HKWorkout) -> Color {
    switch w.workoutActivityType {
    case .hiking:   return Color(red: 0.60, green: 0.95, blue: 0.13)
    case .running:  return .orange
    case .cycling:  return .blue
    case .swimming: return .cyan
    case .traditionalStrengthTraining, .functionalStrengthTraining: return .purple
    case .yoga:     return .pink
    default:        return Color(red: 0.60, green: 0.95, blue: 0.13)
    }
  }

  private func formatDuration(_ t: TimeInterval) -> String {
    let h = Int(t) / 3600; let m = (Int(t) % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
  }

  private func relativeDate(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date)     { return "Today · \(date.formatted(.dateTime.hour().minute()))" }
    if cal.isDateInYesterday(date) { return "Yesterday · \(date.formatted(.dateTime.hour().minute()))" }
    return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
  }

  private func shortDate(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date)     { return "Today" }
    if cal.isDateInYesterday(date) { return "Yesterday" }
    let fmt = DateFormatter(); fmt.dateFormat = "EEE, MMM d"
    return fmt.string(from: date)
  }
}

// MARK: - Small metric tile

struct SmallMetricCard: View {
  let label: String
  let value: String
  let unit: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: icon).font(.title3).foregroundStyle(color)
      Spacer()
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value).font(.system(size: 26, weight: .bold, design: .rounded))
        Text(unit).font(.caption).foregroundStyle(.secondary)
      }
      Text(label).font(.caption).foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  MetricsView().environmentObject(HealthKitManager())
}

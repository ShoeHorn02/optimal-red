import SwiftUI
import HealthKit

struct ContentView: View {
  @EnvironmentObject var workoutManager: WorkoutManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager

  var body: some View {
    if workoutManager.isRecording {
      ActiveWorkoutView()
    } else {
      IdleView()
    }
  }
}

// MARK: - Active Recording

struct ActiveWorkoutView: View {
  @EnvironmentObject var workoutManager: WorkoutManager

  var body: some View {
    VStack(spacing: 6) {
      Text(formatDuration(workoutManager.elapsedTime))
        .font(.system(size: 38, weight: .bold, design: .rounded))
        .foregroundStyle(.red)
        .monospacedDigit()

      Divider()

      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "–")
            .font(.title2.bold())
          Label("BPM", systemImage: "heart.fill")
            .font(.caption2)
            .foregroundStyle(.red)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(String(format: "%.2f", workoutManager.distance))
            .font(.title2.bold())
          Text("km")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      Text(String(format: "%.0f kcal", workoutManager.calories))
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()

      Button(role: .destructive) {
        workoutManager.endWorkout()
      } label: {
        Label("Stop", systemImage: "stop.fill")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .tint(.red)
    }
    .padding(10)
  }

  private func formatDuration(_ t: TimeInterval) -> String {
    let h = Int(t) / 3600
    let m = (Int(t) % 3600) / 60
    let s = Int(t) % 60
    return h > 0
      ? String(format: "%d:%02d:%02d", h, m, s)
      : String(format: "%02d:%02d", m, s)
  }
}

// MARK: - Idle

struct IdleView: View {
  @EnvironmentObject var workoutManager: WorkoutManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager

  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        HStack(spacing: 8) {
          StartButton(label: "Hike", icon: "figure.hiking", color: .red) {
            workoutManager.startWorkout(type: .hiking)
          }
          StartButton(label: "Walk", icon: "figure.walk", color: .blue) {
            workoutManager.startWorkout(type: .walking)
          }
        }

        Divider()

        MetricRow(icon: "heart.fill",      color: .red,    value: "\(Int(workoutManager.heartRate))", unit: "bpm")
        MetricRow(icon: "figure.hiking",   color: .green,  value: String(format: "%.2f", workoutManager.distance), unit: "km")
        MetricRow(icon: "flame.fill",      color: .orange, value: "\(Int(workoutManager.calories))", unit: "kcal")

        HStack(spacing: 4) {
          Circle()
            .fill(watchConnectivityManager.isConnected ? Color.green : Color.gray)
            .frame(width: 6, height: 6)
          Text("iPhone")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .padding(8)
    }
    .onAppear {
      workoutManager.requestAuthorization()
    }
  }
}

struct StartButton: View {
  let label: String
  let icon: String
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.title3)
        Text(label)
          .font(.caption2.weight(.semibold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
    }
    .buttonStyle(.bordered)
    .tint(color)
  }
}

struct MetricRow: View {
  let icon: String
  let color: Color
  let value: String
  let unit: String

  var body: some View {
    HStack {
      Image(systemName: icon)
        .font(.caption)
        .foregroundStyle(color)
        .frame(width: 18)
      Spacer()
      HStack(spacing: 2) {
        Text(value)
          .font(.caption.weight(.semibold))
        Text(unit)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(WorkoutManager())
    .environmentObject(WatchConnectivityManager())
}

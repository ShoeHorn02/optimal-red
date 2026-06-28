import SwiftUI

struct RecordingView: View {
  @EnvironmentObject var recordingManager: WorkoutRecordingManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      if recordingManager.isRecording {
        activeView
      } else {
        startView
      }
    }
  }

  // MARK: - Start screen

  private var startView: some View {
    VStack(spacing: 32) {
      VStack(spacing: 8) {
        Image(systemName: "figure.hiking")
          .font(.system(size: 52))
          .foregroundStyle(.red)
        Text("Record a workout")
          .font(.title2.bold())
        Text("Your Apple Watch will track GPS, heart rate, and elevation automatically.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }

      watchStatus

      HStack(spacing: 16) {
        WorkoutTypeButton(label: "Hike", icon: "figure.hiking", color: .red) {
          recordingManager.startHike()
        }
        WorkoutTypeButton(label: "Walk", icon: "figure.walk", color: .blue) {
          recordingManager.startWalk()
        }
      }
      .padding(.horizontal)

      Spacer()
    }
    .padding(.top, 40)
    .navigationTitle("New Workout")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button("Cancel") { dismiss() }
      }
    }
  }

  private var watchStatus: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(watchConnectivityManager.isConnected ? Color.green : Color.orange)
        .frame(width: 8, height: 8)
      Text(watchConnectivityManager.isConnected
           ? "Apple Watch ready"
           : "Apple Watch not reachable — open the Watch app first")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 10)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
  }

  // MARK: - Active recording screen

  private var activeView: some View {
    VStack(spacing: 0) {
      // Type badge
      Label(recordingManager.currentType == .hike ? "Hiking" : "Walking",
            systemImage: recordingManager.currentType == .hike ? "figure.hiking" : "figure.walk")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.top, 8)

      Spacer()

      // Elapsed time
      Text(formatDuration(recordingManager.elapsedTime))
        .font(.system(size: 64, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.red)

      Spacer()

      // Live metrics grid
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        LiveMetricCard(value: recordingManager.liveHeartRate > 0
                       ? "\(Int(recordingManager.liveHeartRate))" : "–",
                       unit: "bpm", label: "Heart Rate", icon: "heart.fill", color: .red)
        LiveMetricCard(value: String(format: "%.2f", recordingManager.liveDistance),
                       unit: "km", label: "Distance", icon: "figure.walk", color: .blue)
        LiveMetricCard(value: String(format: "%.0f", recordingManager.liveCalories),
                       unit: "kcal", label: "Calories", icon: "flame.fill", color: .orange)
      }
      .padding(.horizontal)

      Spacer()

      Button(role: .destructive) {
        recordingManager.stopRecording()
        dismiss()
      } label: {
        Label("Stop & Save", systemImage: "stop.fill")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding()
      }
      .buttonStyle(.bordered)
      .tint(.red)
      .padding(.horizontal)
      .padding(.bottom)
    }
    .navigationTitle("Recording")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden()
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

// MARK: - Supporting views

struct WorkoutTypeButton: View {
  let label: String
  let icon: String
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 36))
          .foregroundStyle(color)
        Text(label)
          .font(.headline)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 28)
      .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
      .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3), lineWidth: 1))
    }
    .buttonStyle(.plain)
  }
}

struct LiveMetricCard: View {
  let value: String
  let unit: String
  let label: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(color)
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value)
          .font(.system(size: 28, weight: .bold, design: .rounded))
        Text(unit)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
  }
}

#Preview {
  RecordingView()
    .environmentObject(WorkoutRecordingManager())
    .environmentObject(WatchConnectivityManager())
}

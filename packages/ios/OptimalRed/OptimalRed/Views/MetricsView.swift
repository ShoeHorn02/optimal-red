import SwiftUI

struct MetricsView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
  @EnvironmentObject var recordingManager: WorkoutRecordingManager
  @State private var showingRecording = false

  private var greeting: String {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 0..<12: return "Good morning"
    case 12..<17: return "Good afternoon"
    default: return "Good evening"
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          watchStatusPill

          HeartRateCard(heartRate: healthKitManager.heartRate)

          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            SmallMetricCard(label: "Distance",  value: String(format: "%.2f", healthKitManager.distance),  unit: "km",   icon: "figure.walk",     color: .blue)
            SmallMetricCard(label: "Elevation", value: String(format: "%.0f", healthKitManager.elevation), unit: "m",    icon: "mountain.2.fill", color: .green)
            SmallMetricCard(label: "Calories",  value: String(format: "%.0f", healthKitManager.calories),  unit: "kcal", icon: "flame.fill",      color: .orange)
          }

          // Live session card (shows when Fitness app or any HK source is active)
          if healthKitManager.isLiveSessionActive {
            LiveSessionCard(
              heartRate: healthKitManager.liveHeartRate,
              distance: healthKitManager.liveDistance,
              calories: healthKitManager.liveCalories
            )
          }

          // Record button
          Button {
            showingRecording = true
          } label: {
            HStack {
              Image(systemName: recordingManager.isRecording ? "waveform.circle.fill" : "record.circle")
                .font(.title3)
              Text(recordingManager.isRecording ? "Recording…" : "Record workout")
                .font(.headline)
              Spacer()
              if recordingManager.isRecording {
                Text(formatDuration(recordingManager.elapsedTime))
                  .font(.subheadline.monospacedDigit())
                  .foregroundStyle(.red)
              }
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(recordingManager.isRecording
                        ? Color.red.opacity(0.12)
                        : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(recordingManager.isRecording ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1)
            )
          }
          .foregroundStyle(recordingManager.isRecording ? .red : .primary)
          .buttonStyle(.plain)
        }
        .padding()
      }
      .navigationTitle(greeting)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            healthKitManager.startHealthKitUpdates()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
      .onAppear {
        healthKitManager.requestAuthorization()
        healthKitManager.startHealthKitUpdates()
        healthKitManager.startLiveObservation()
        watchConnectivityManager.startWatchConnectivity()
      }
      .onDisappear {
        healthKitManager.stopLiveObservation()
      }
      .sheet(isPresented: $showingRecording) {
        RecordingView()
      }
      .onReceive(NotificationCenter.default.publisher(for: .startHike)) { _ in
        showingRecording = true
      }
      .onReceive(NotificationCenter.default.publisher(for: .startWalk)) { _ in
        showingRecording = true
      }
    }
  }

  private func formatDuration(_ t: TimeInterval) -> String {
    let h = Int(t) / 3600
    let m = (Int(t) % 3600) / 60
    let s = Int(t) % 60
    return h > 0
      ? String(format: "%d:%02d:%02d", h, m, s)
      : String(format: "%02d:%02d", m, s)
  }

  private var watchStatusPill: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(watchConnectivityManager.isConnected ? Color.green : Color.secondary.opacity(0.5))
        .frame(width: 7, height: 7)
      Text(watchConnectivityManager.isConnected ? "Apple Watch connected" : "Apple Watch not found")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Cards

struct LiveSessionCard: View {
  let heartRate: Double
  let distance: Double
  let calories: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Circle()
          .fill(.green)
          .frame(width: 8, height: 8)
          .opacity(0.9)
        Text("Live session detected")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
        Spacer()
        Text("from Health")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      HStack(spacing: 0) {
        liveCell(value: heartRate > 0 ? String(format: "%.0f", heartRate) : "–", unit: "BPM",  icon: "heart.fill",  color: .red)
        Divider().frame(height: 36)
        liveCell(value: String(format: "%.2f", distance), unit: "km",   icon: "figure.walk", color: .blue)
        Divider().frame(height: 36)
        liveCell(value: String(format: "%.0f", calories), unit: "kcal", icon: "flame.fill",  color: .orange)
      }
    }
    .padding()
    .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.green.opacity(0.25), lineWidth: 1))
  }

  private func liveCell(value: String, unit: String, icon: String, color: Color) -> some View {
    VStack(spacing: 2) {
      Image(systemName: icon).font(.caption).foregroundStyle(color)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(value).font(.subheadline.weight(.bold).monospacedDigit())
        Text(unit).font(.caption2).foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 6)
  }
}

struct HeartRateCard: View {
  let heartRate: Double

  var body: some View {
    RoundedRectangle(cornerRadius: 20)
      .fill(.red.gradient)
      .frame(height: 150)
      .overlay(
        HStack {
          VStack(alignment: .leading, spacing: 6) {
            Label("Heart Rate", systemImage: "heart.fill")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.white.opacity(0.85))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
              Text(heartRate > 0 ? String(format: "%.0f", heartRate) : "–")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
              Text("BPM")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, 4)
            }
          }
          Spacer()
          Image(systemName: "heart.fill")
            .font(.system(size: 56))
            .foregroundStyle(.white.opacity(0.12))
        }
        .padding(20)
      )
  }
}

struct SmallMetricCard: View {
  let label: String
  let value: String
  let unit: String
  let icon: String
  let color: Color

  var body: some View {
    RoundedRectangle(cornerRadius: 16)
      .fill(Color(.secondarySystemBackground))
      .frame(height: 120)
      .overlay(
        VStack(alignment: .leading, spacing: 0) {
          Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(color)

          Spacer()

          HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
              .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(unit)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
      )
  }
}

#Preview {
  MetricsView()
    .environmentObject(HealthKitManager())
    .environmentObject(WatchConnectivityManager())
    .environmentObject(WorkoutRecordingManager())
}

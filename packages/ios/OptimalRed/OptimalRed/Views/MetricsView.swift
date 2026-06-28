import SwiftUI

struct MetricsView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager

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
            SmallMetricCard(label: "Distance",  value: String(format: "%.2f", healthKitManager.distance),  unit: "km",   icon: "figure.walk",       color: .blue)
            SmallMetricCard(label: "Elevation", value: String(format: "%.0f", healthKitManager.elevation), unit: "m",    icon: "mountain.2.fill",   color: .green)
            SmallMetricCard(label: "Calories",  value: String(format: "%.0f", healthKitManager.calories),  unit: "kcal", icon: "flame.fill",        color: .orange)
          }
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
        watchConnectivityManager.startWatchConnectivity()
      }
    }
  }

  private var watchStatusPill: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(watchConnectivityManager.isConnected ? Color.green : Color(.systemGray3))
        .frame(width: 7, height: 7)
      Text(watchConnectivityManager.isConnected ? "Apple Watch connected" : "Apple Watch not found")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Cards

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
}

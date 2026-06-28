import SwiftUI

struct ContentView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager

  var body: some View {
    VStack(spacing: 12) {
      Text("Optimal Red")
        .font(.headline)
        .foregroundColor(.red)

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          MetricRow(
            label: "Heart Rate",
            value: String(format: "%.0f", healthKitManager.heartRate),
            unit: "bpm"
          )

          MetricRow(
            label: "Distance",
            value: String(format: "%.2f", healthKitManager.distance),
            unit: "km"
          )

          MetricRow(
            label: "Elevation",
            value: String(format: "%.0f", healthKitManager.elevation),
            unit: "m"
          )

          MetricRow(
            label: "Calories",
            value: String(format: "%.0f", healthKitManager.calories),
            unit: "kcal"
          )
        }
        .padding(.horizontal, 8)
      }

      HStack(spacing: 8) {
        if watchConnectivityManager.isConnected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.caption)
        } else {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.gray)
            .font(.caption)
        }
        Text("iPhone")
          .font(.caption)
      }
    }
    .padding()
    .onAppear {
      healthKitManager.requestAuthorization()
      healthKitManager.startHealthKitUpdates()
      watchConnectivityManager.startWatchConnectivity()
    }
  }
}

struct MetricRow: View {
  let label: String
  let value: String
  let unit: String

  var body: some View {
    HStack {
      Text(label)
        .font(.caption)
        .foregroundColor(.gray)
      Spacer()
      HStack(spacing: 2) {
        Text(value)
          .font(.caption2)
          .fontWeight(.semibold)
        Text(unit)
          .font(.caption2)
          .foregroundColor(.gray)
      }
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(HealthKitManager())
    .environmentObject(WatchConnectivityManager())
}

import SwiftUI

struct MetricsView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          Text("Today's Metrics")
            .font(.title2)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

          VStack(spacing: 12) {
            MetricCard(
              label: "Heart Rate",
              value: String(format: "%.0f", healthKitManager.heartRate),
              unit: "bpm",
              icon: "heart.fill",
              color: .red
            )

            MetricCard(
              label: "Distance",
              value: String(format: "%.2f", healthKitManager.distance),
              unit: "km",
              icon: "figure.walk",
              color: .blue
            )

            MetricCard(
              label: "Elevation",
              value: String(format: "%.0f", healthKitManager.elevation),
              unit: "m",
              icon: "mountain.2.fill",
              color: .green
            )

            MetricCard(
              label: "Calories",
              value: String(format: "%.0f", healthKitManager.calories),
              unit: "kcal",
              icon: "flame.fill",
              color: .orange
            )
          }
          .padding(.horizontal)

          HStack {
            Image(systemName: watchConnectivityManager.isConnected ? "checkmark.circle.fill" : "xmark.circle")
              .foregroundColor(watchConnectivityManager.isConnected ? .green : .gray)
            Text(watchConnectivityManager.isConnected ? "Connected to Apple Watch" : "Apple Watch disconnected")
              .font(.caption)
              .foregroundColor(.gray)
            Spacer()
          }
          .padding()
          .background(Color(.systemGray6))
          .cornerRadius(8)
          .padding(.horizontal)
        }
        .padding(.vertical)
      }
      .navigationTitle("Optimal Red")
      .onAppear {
        healthKitManager.requestAuthorization()
        healthKitManager.startHealthKitUpdates()
        watchConnectivityManager.startWatchConnectivity()
      }
    }
  }
}

struct MetricCard: View {
  let label: String
  let value: String
  let unit: String
  let icon: String
  let color: Color

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(color)
        .frame(width: 40)

      VStack(alignment: .leading, spacing: 4) {
        Text(label)
          .font(.caption)
          .foregroundColor(.gray)
        HStack(spacing: 2) {
          Text(value)
            .font(.title3)
            .fontWeight(.semibold)
          Text(unit)
            .font(.caption)
            .foregroundColor(.gray)
        }
      }

      Spacer()
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

#Preview {
  MetricsView()
    .environmentObject(HealthKitManager())
    .environmentObject(WatchConnectivityManager())
}

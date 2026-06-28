import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
  @State private var autoRefresh = true

  var body: some View {
    NavigationStack {
      List {
        Section("Watch") {
          LabeledContent("Status") {
            HStack(spacing: 6) {
              Circle()
                .fill(watchConnectivityManager.isConnected ? Color.green : Color(.systemGray3))
                .frame(width: 8, height: 8)
              Text(watchConnectivityManager.isConnected ? "Connected" : "Disconnected")
                .foregroundStyle(watchConnectivityManager.isConnected ? .primary : .secondary)
                .font(.subheadline)
            }
          }
        }

        Section("Health Data") {
          LabeledContent("HealthKit Access") {
            Text(healthKitManager.isAuthorized ? "Granted" : "Not granted")
              .foregroundStyle(healthKitManager.isAuthorized ? .green : .red)
              .font(.subheadline)
          }
          Toggle("Auto-Refresh", isOn: $autoRefresh)
        }

        Section("About") {
          LabeledContent("Version", value: "0.1.0")
          LabeledContent("Phase", value: "MVP")
        }
      }
      .navigationTitle("Settings")
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(HealthKitManager())
    .environmentObject(WatchConnectivityManager())
}

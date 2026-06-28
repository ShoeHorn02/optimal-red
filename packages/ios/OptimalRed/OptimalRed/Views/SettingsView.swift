import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
  @State private var enableCloudSync = false
  @State private var autoRefresh = true

  var body: some View {
    NavigationStack {
      Form {
        Section("Health Data") {
          HStack {
            Text("HealthKit Access")
            Spacer()
            Text(healthKitManager.isAuthorized ? "Granted" : "Denied")
              .foregroundColor(healthKitManager.isAuthorized ? .green : .red)
          }
        }

        Section("Watch Connection") {
          HStack {
            Text("Status")
            Spacer()
            HStack(spacing: 4) {
              Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundColor(watchConnectivityManager.isConnected ? .green : .gray)
              Text(watchConnectivityManager.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
            }
          }
        }

        Section("Sync Settings") {
          Toggle("Auto-Refresh", isOn: $autoRefresh)
          Toggle("Enable Cloud Sync", isOn: $enableCloudSync)
        }

        Section("About") {
          HStack {
            Text("Version")
            Spacer()
            Text("0.0.1")
              .foregroundColor(.gray)
          }

          HStack {
            Text("Bundle ID")
            Spacer()
            Text("app.optimalred.ios")
              .font(.caption)
              .foregroundColor(.gray)
          }
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

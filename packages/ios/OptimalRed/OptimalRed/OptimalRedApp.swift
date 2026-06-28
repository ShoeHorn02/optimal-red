import SwiftUI
import SwiftData

@main
struct OptimalRedApp: App {
  @StateObject private var healthKitManager = HealthKitManager()
  @StateObject private var watchConnectivityManager = WatchConnectivityManager()
  let modelContainer: ModelContainer

  init() {
    do {
      modelContainer = try ModelContainer(
        for: StoredHealthMetric.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: false)
      )
    } catch {
      fatalError("Could not initialize ModelContainer: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      TabView {
        MetricsView()
          .environmentObject(healthKitManager)
          .environmentObject(watchConnectivityManager)
          .tabItem {
            Label("Today", systemImage: "heart.fill")
          }

        HistoryView()
          .modelContainer(modelContainer)
          .tabItem {
            Label("History", systemImage: "chart.bar.fill")
          }

        SettingsView()
          .tabItem {
            Label("Settings", systemImage: "gear")
          }
      }
    }
    .modelContainer(modelContainer)
  }
}

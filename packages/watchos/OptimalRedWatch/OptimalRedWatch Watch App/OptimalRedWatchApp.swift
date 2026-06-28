import SwiftUI

@main
struct OptimalRedWatchApp: App {
  @StateObject private var healthKitManager = HealthKitManager()
  @StateObject private var watchConnectivityManager = WatchConnectivityManager()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(healthKitManager)
        .environmentObject(watchConnectivityManager)
    }
  }
}

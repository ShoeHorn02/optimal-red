import SwiftUI

@main
struct OptimalRedWatchApp: App {
  @StateObject private var workoutManager = WorkoutManager()
  @StateObject private var watchConnectivityManager = WatchConnectivityManager()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(workoutManager)
        .environmentObject(watchConnectivityManager)
        .onAppear {
          watchConnectivityManager.workoutManager = workoutManager
          workoutManager.requestAuthorization()
        }
    }
  }
}

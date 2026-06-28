import SwiftUI
import SwiftData

@main
struct OptimalRedApp: App {
  @StateObject private var healthKitManager = HealthKitManager()
  @StateObject private var watchConnectivityManager = WatchConnectivityManager()
  @StateObject private var recordingManager = WorkoutRecordingManager()
  @State private var showRecording = false

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
          .tabItem { Label("Today", systemImage: "heart.fill") }

        MapRouteView()
          .tabItem { Label("Map", systemImage: "map.fill") }

        HistoryView()
          .tabItem { Label("History", systemImage: "chart.bar.fill") }

        SettingsView()
          .tabItem { Label("Settings", systemImage: "gear") }
      }
      .environmentObject(healthKitManager)
      .environmentObject(watchConnectivityManager)
      .environmentObject(recordingManager)
      .sheet(isPresented: $showRecording) {
        RecordingView()
          .environmentObject(recordingManager)
          .environmentObject(watchConnectivityManager)
      }
      .onReceive(NotificationCenter.default.publisher(for: .startHike)) { _ in
        recordingManager.startHike()
        showRecording = true
      }
      .onReceive(NotificationCenter.default.publisher(for: .startWalk)) { _ in
        recordingManager.startWalk()
        showRecording = true
      }
      .onReceive(NotificationCenter.default.publisher(for: .stopRecording)) { _ in
        recordingManager.stopRecording()
        showRecording = false
      }
      .onAppear {
        watchConnectivityManager.recordingManager = recordingManager
        watchConnectivityManager.setModelContext(modelContainer.mainContext)
      }
    }
    .modelContainer(modelContainer)
  }
}

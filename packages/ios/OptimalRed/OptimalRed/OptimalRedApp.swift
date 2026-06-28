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
    let schema = Schema([StoredHealthMetric.self])
    // cloudKitDatabase: .none — we use our own CloudKitSyncService; SwiftData stays local
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

    if let container = try? ModelContainer(for: schema, configurations: config) {
      modelContainer = container
      return
    }

    // Store corrupted or old schema — wipe every file whose name starts with "default.store"
    if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
       let files = try? FileManager.default.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil) {
      for file in files where file.lastPathComponent.hasPrefix("default.store") {
        try? FileManager.default.removeItem(at: file)
      }
    }

    // Second attempt after wipe
    if let container = try? ModelContainer(for: schema, configurations: config) {
      modelContainer = container
      return
    }

    // Last resort: in-memory (data comes from HealthKit anyway)
    modelContainer = try! ModelContainer(
      for: schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
  }

  var body: some Scene {
    WindowGroup {
      TabView {
        MetricsView()
          .tabItem { Label("Activity", systemImage: "figure.run") }

        MapRouteView()
          .tabItem { Label("Map", systemImage: "map.fill") }

        HistoryView()
          .tabItem { Label("History", systemImage: "list.bullet") }

        SettingsView()
          .tabItem { Label("Settings", systemImage: "gear") }
      }
      .preferredColorScheme(.dark)
      .environmentObject(healthKitManager)
      .environmentObject(watchConnectivityManager)
      .environmentObject(recordingManager)
      .onAppear {
        watchConnectivityManager.recordingManager = recordingManager
        watchConnectivityManager.setModelContext(modelContainer.mainContext)
      }
    }
    .modelContainer(modelContainer)
  }
}

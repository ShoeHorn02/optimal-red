import AppIntents

// MARK: - Start Hike

struct StartHikeIntent: AppIntent {
  static var title: LocalizedStringResource = "Start a Hike"
  static var description = IntentDescription("Begin recording a hiking workout in Optimal Red.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .startHike, object: nil)
    return .result()
  }
}

// MARK: - Start Walk

struct StartWalkIntent: AppIntent {
  static var title: LocalizedStringResource = "Start a Walk"
  static var description = IntentDescription("Begin recording a walking workout in Optimal Red.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .startWalk, object: nil)
    return .result()
  }
}

// MARK: - Stop Recording

struct StopRecordingIntent: AppIntent {
  static var title: LocalizedStringResource = "Stop Recording"
  static var description = IntentDescription("Stop the current workout recording in Optimal Red.")
  static var openAppWhenRun: Bool = true

  @MainActor
  func perform() async throws -> some IntentResult {
    NotificationCenter.default.post(name: .stopRecording, object: nil)
    return .result()
  }
}

// MARK: - App Shortcuts (Siri phrases)

struct OptimalRedShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartHikeIntent(),
      phrases: [
        "Begin hike in \(.applicationName)",
        "Start a hike in \(.applicationName)",
        "Start hiking in \(.applicationName)",
      ],
      shortTitle: "Start Hike",
      systemImageName: "figure.hiking"
    )
    AppShortcut(
      intent: StartWalkIntent(),
      phrases: [
        "Begin walk in \(.applicationName)",
        "Start a walk in \(.applicationName)",
        "Start walking in \(.applicationName)",
      ],
      shortTitle: "Start Walk",
      systemImageName: "figure.walk"
    )
    AppShortcut(
      intent: StopRecordingIntent(),
      phrases: [
        "Stop recording in \(.applicationName)",
        "End workout in \(.applicationName)",
        "Stop my workout in \(.applicationName)",
      ],
      shortTitle: "Stop Recording",
      systemImageName: "stop.fill"
    )
  }
}

// MARK: - Notification names

extension Notification.Name {
  static let startHike      = Notification.Name("com.optimalred.startHike")
  static let startWalk      = Notification.Name("com.optimalred.startWalk")
  static let stopRecording  = Notification.Name("com.optimalred.stopRecording")
}

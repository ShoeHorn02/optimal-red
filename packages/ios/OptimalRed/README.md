# Optimal Red iOS App

iPhone app for Optimal Red health tracking platform.

## Features

- Receive and display metrics from Apple Watch
- Store metrics in SwiftData (local database)
- View today's metrics (heart rate, distance, elevation, calories)
- View historical metrics in list view
- Settings for HealthKit and cloud sync
- Real-time Watch Connection status

## Setup

1. Open `OptimalRed.xcodeproj` in Xcode
2. Set Team ID (Xcode → Preferences → Accounts)
3. Set Bundle ID to `app.optimalred.ios`
4. Select iPhone as build target
5. Enable HealthKit and iCloud (CloudKit) capabilities in Xcode
6. Build and run on iPhone simulator or device

## Structure

```
OptimalRed/
├── OptimalRedApp.swift            # App entry point with SwiftData
├── Views/
│   ├── MetricsView.swift          # Today's metrics display
│   ├── HistoryView.swift          # Historical metrics list
│   └── SettingsView.swift         # Settings UI
├── Services/
│   ├── HealthKitManager.swift     # HealthKit integration
│   └── WatchConnectivityManager.swift  # Watch communication + storage
├── Persistence/
│   └── StoredHealthMetric.swift   # SwiftData model
└── OptimalRedWatchConnector/
    └── WatchConnectivityBridge.swift
```

## Key Files

- **OptimalRedApp.swift** - Main app with SwiftData ModelContainer
- **WatchConnectivityManager.swift** - Receives metrics from Watch and stores in SwiftData
- **StoredHealthMetric.swift** - SwiftData model for persisting metrics
- **MetricsView.swift** - Displays today's metrics
- **HistoryView.swift** - Lists all stored metrics
- **SettingsView.swift** - App settings

## Data Flow

1. Watch sends metrics via WatchConnectivity message
2. `WatchConnectivityManager.session(didReceiveMessage:)` receives data
3. Metrics are stored in SwiftData via `StoredHealthMetric`
4. Views query SwiftData with `@Query` macro and display data

## Notes

- Requires iOS 17+ 
- HealthKit permissions needed
- Needs app.optimalred.ios Bundle ID registered in App Store Connect
- SwiftData stores metrics locally - works offline
- Phase 1: Will add cloud sync to backend

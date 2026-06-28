# Optimal Red Watch App

watchOS companion app for Apple Watch.

## Features

- Heart rate monitoring
- Distance tracking
- Elevation gain
- Calorie burn tracking
- Real-time sync to iPhone via WatchConnectivity

## Setup

1. Open `OptimalRedWatch.xcodeproj` in Xcode
2. Set Team ID (Xcode → Preferences → Accounts)
3. Set Bundle ID to `app.optimalred.watchos`
4. Select Apple Watch as build target
5. Enable HealthKit capability in Xcode
6. Build and run on Apple Watch simulator or device

## Structure

```
OptimalRedWatch/
├── OptimalRedWatchApp.swift       # App entry point
├── Views/
│   └── ContentView.swift          # Main UI
├── Services/
│   ├── HealthKitManager.swift     # HealthKit integration
│   └── WatchConnectivityManager.swift  # iPhone communication
└── Models/
```

## Key Files

- **HealthKitManager.swift** - Fetches HR, distance, elevation, calories from HealthKit
- **WatchConnectivityManager.swift** - Sends metrics to iPhone every 15 minutes
- **ContentView.swift** - Displays metrics on Watch face

## Notes

- Requires iOS 17+ and watchOS 10+
- HealthKit permissions needed for heart rate, distance, elevation, calories
- Needs app.optimalred.watchos Bundle ID registered in App Store Connect

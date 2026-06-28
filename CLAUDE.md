# Optimal Red - Apple Health Tracking Platform

## Project Overview

Optimal Red is a comprehensive health tracking application for Apple ecosystem devices. It captures health metrics (heart rate, distance, elevation, calories) from an Apple Watch, syncs to iPhone, and eventually displays data on Mac and web dashboards.

**Vision**: Create the macOS app that Apple Fitness+ doesn't have, with deep HealthKit integration across watch, phone, and Mac.

**Domain**: optimalred.app (registered on Namecheap, managed by DigitalOcean DNS)

## Current Status

**Phase**: Phase 0 → Phase 1 transition
**Date Started**: 2026-06-27
**Last Updated**: 2026-06-28
**GitHub**: https://github.com/ShoeHorn02/optimal-red

### What's Done
- [x] Monorepo structure created (packages: shared, watchos, ios, macos, backend)
- [x] Shared types package initialized (health metrics, user models)
- [x] Backend package template created (Next.js + Drizzle)
- [x] GitHub repository created
- [x] Watch app — built & running on simulator
- [x] iPhone app — built & running on simulator
- [x] HealthKit integration on both Watch & iPhone
- [x] HealthKit permission strings in build settings
- [x] WatchConnectivity setup for Watch ↔ iPhone communication
- [x] SwiftData persistence on iPhone (StoredHealthMetric model)
- [x] TabView UI: Today, Map (GPS route from HealthKit), History, Settings
- [x] MapKit hike map (satellite, red polyline, start/finish annotations, workout picker)
- [x] **Workout recording**: tap Record on iPhone → HKWorkoutSession starts on Watch → streams live HR/distance/calories back to iPhone every 3s
- [x] **Siri AppIntents**: "Begin hike in Optimal Red" / "Begin walk in Optimal Red" / "Stop recording in Optimal Red"
- [x] Watch recording UI: live timer, HR, distance, stop button
- [x] App icon from HeartHealth branding (heart + ECG pulse, dark bg)
- [x] fastlane configured: `fastlane build`, `fastlane beta` (TestFlight upload)
- [x] fastlane .env.local filled with ASC API key — TestFlight deploys working
- [x] **Watch app embedded inside iOS Xcode project** — one IPA ships both apps; Watch auto-installs when user installs the iPhone app (Build 6 on TestFlight)
- [ ] Provision real devices for on-device testing
- [ ] CI/CD GitHub Actions workflows
- [ ] Backend database schema

## MVP Status (Phase 0)

**✅ Working:**
- Watch app fetches HealthKit data: heart rate, distance, elevation, calories
- Watch displays today's metrics + Hike/Walk start buttons
- iPhone receives passive metrics via WatchConnectivity
- iPhone stores metrics in SwiftData
- iPhone displays today's metrics in MetricsView
- iPhone shows GPS workout routes in MapRouteView (hybrid satellite, red polyline)
- iPhone shows historical metrics in HistoryView
- Settings view shows connection status
- **Workout recording**: iPhone → Watch command → HKWorkoutSession + HKLiveWorkoutBuilder → live metrics stream → iPhone displays live timer, HR, distance, calories
- **Siri**: "Begin hike in Optimal Red", "Begin walk in Optimal Red", "Stop recording in Optimal Red"
- Both apps build and run on simulators
- App icon updated (HeartHealth SVG design: dark bg, red heart, ECG pulse line)
- fastlane fully working — `fastlane build` tests every change, `fastlane beta` uploads to TestFlight
- **Watch embedded in iOS project** — `OptimalRed.xcworkspace` references both; single IPA includes Watch companion (auto-installs on paired Watch)

**⚠️ Known Simulator Limitation:**
- WatchConnectivity between simulators requires paired simulators (iOS + watchOS)
- Must launch both from Xcode using a paired scheme — running them independently won't connect
- Use Window → Devices and Simulators in Xcode to verify pairing

**🚀 Ready for:**
- End-to-end Watch → iPhone data transmission test (paired simulators)
- Manual testing on real devices (requires provisioning profiles)
- TestFlight beta distribution

**Next Phase (Phase 1):**
- Add cloud backend (Next.js + PostgreSQL)
- Implement sync engine on iPhone
- Add Apple Sign-in authentication
- Deploy to DigitalOcean

## Architecture

### Monorepo Structure
```
optimal-red/
├── packages/
│   ├── shared/           ← Shared types (HealthMetric, User, sync protocol)
│   ├── watchos/          ← Watch app source (embedded inside iOS project at build time)
│   ├── ios/              ← iPhone app (hub: storage + sync engine)
│   │   └── OptimalRed/
│   │       ├── OptimalRed.xcworkspace   ← Open this in Xcode (references both projects)
│   │       ├── OptimalRed.xcodeproj     ← iOS project (embeds Watch via cross-project ref)
│   │       └── fastlane/                ← Build & TestFlight automation
│   ├── macos/            ← Mac app (Phase 2)
│   └── backend/          ← Next.js backend (Phase 1)
├── .github/workflows/    ← CI/CD
└── CLAUDE.md
```

### Watch + iPhone Bundling
The Watch app is **embedded inside the iOS Xcode project**, not a separate submission:
- `OptimalRed.xcworkspace` references both `OptimalRed.xcodeproj` and `OptimalRedWatch.xcodeproj`
- `OptimalRed.xcodeproj` has a cross-project reference to the Watch project with a `PBXTargetDependency` and an "Embed Watch Content" `PBXCopyFilesBuildPhase`
- One `fastlane beta` → one IPA → one App Store Connect app → Watch auto-installs on paired Apple Watch when user installs the iPhone app
- Watch bundle ID: `app.optimalred.watchos.watchkitapp`, companion set to `app.optimalred.ios`

### Data Flow
```
Apple Watch (HealthKit + HKWorkoutSession)
  │  passive sync every 15 min (WatchConnectivity applicationContext)
  │  live workout stream every 3s (WatchConnectivity sendMessage)
  ↓
iPhone (SwiftData hub)
  │  stores StoredHealthMetric via SwiftData
  │  displays: Today metrics, MapKit GPS routes, History, live recording UI
  ↓ [HTTPS — Phase 1]
Backend (Next.js + PostgreSQL on DigitalOcean)
  ↓
Mac App + Web Dashboard (Phase 2/3)
```

### Workout Recording Flow
```
iPhone RecordingView
  → WorkoutRecordingManager.startHike/startWalk()
  → WCSession.sendMessage(["command": "startHike"])
  → Watch WatchConnectivityManager receives command
  → WorkoutManager.startWorkout(type:)
  → HKWorkoutSession + HKLiveWorkoutBuilder start on Watch
  → workoutBuilder(_:didCollectDataOf:) fires on new HR/distance/calories
  → broadcastToPhone() every 3s via WCSession.sendMessage
  → iPhone WatchConnectivityService routes to WorkoutRecordingManager.handleLiveUpdate()
  → RecordingView updates live timer, HR, distance, calories
```

### Siri Integration
```
"Begin hike in Optimal Red"  → StartHikeIntent.perform()
"Begin walk in Optimal Red"  → StartWalkIntent.perform()
"Stop recording in Optimal Red" → StopRecordingIntent.perform()
  → NotificationCenter.post(.startHike / .startWalk / .stopRecording)
  → OptimalRedApp receives notification → triggers WorkoutRecordingManager
```

### Technology Stack
- **watchOS**: SwiftUI + HealthKit + HKWorkoutSession + HKLiveWorkoutBuilder
- **iOS**: SwiftUI + SwiftData + AppIntents (Siri) + MapKit
- **IPC**: WatchConnectivity (passive applicationContext + live sendMessage)
- **macOS**: SwiftUI (Phase 2)
- **Backend**: Next.js + TypeScript + Drizzle ORM + PostgreSQL
- **Cloud**: DigitalOcean (App Platform + Managed PostgreSQL)
- **Auth**: Apple Sign-in (Phase 1)
- **CI/Build**: fastlane (gym + pilot) using `OptimalRed.xcworkspace`

## Phasing

### Phase 0: MVP (Current - 4-6 weeks)
**Goal**: Prove Watch + iPhone health tracking end-to-end

**Watch App**:
- HealthKit integration (Heart Rate, Distance, Elevation, Calories)
- Simple metrics view
- Send to iPhone via WatchConnectivity every 15 minutes
- Works offline (no internet required)

**iPhone App**:
- Receive Watch data via WatchConnectivity
- Store in SwiftData (local persistence)
- Tab 1: Today's metrics
- Tab 2: History (charts)
- Tab 3: Settings
- Works offline (no backend yet)

**Deliverables**:
- Xcode projects (Watch + iPhone)
- GitHub monorepo
- TestFlight beta

**Success Metrics**:
- Watch sends 5+ metrics/day reliably
- iPhone displays history
- No crashes in 7-day user test

### Phase 1: Cloud Sync (4-6 weeks after Phase 0)
**Goal**: Add cloud persistence & multi-device visibility

**Backend**:
- Next.js API: `/api/health/sync`, `/api/health/metrics`
- PostgreSQL database
- Apple Sign-in authentication
- Sync conflict resolution

**iPhone Enhancement**:
- CloudSyncService (detect changes → batch → HTTP POST)
- Retry logic + offline queue
- Settings: enable/disable cloud sync

**Web Dashboard** (basic):
- Login with Apple
- View health metrics timeline

**Deliverables**:
- Deployed backend on DigitalOcean
- Updated iPhone with sync
- Basic web dashboard

### Phase 2: Mac App (4-6 weeks after Phase 1)
**Goal**: Native macOS dashboard

**Mac App**:
- SwiftUI native app
- Read health data from backend
- Optional: annotations/notes
- Sync notes back to cloud

**Deliverables**:
- Mac app on App Store

### Phase 3: Web Analytics (Ongoing)
**Goal**: Browser-based health analytics

**Features**:
- Interactive charts (Recharts/D3)
- Trends & analysis (7-day, 30-day, 90-day)
- Export (CSV/PDF)
- Responsive design

## Key Files

### Shared Types
- `packages/shared/src/models/health-metrics.ts` - HealthMetric, DailyMetrics, constants
- `packages/shared/src/models/user.ts` - User, AuthToken, SyncSession

### Watch App
- `packages/watchos/OptimalRedWatch/OptimalRedWatch Watch App/OptimalRedWatchApp.swift` - App entry point
- `packages/watchos/OptimalRedWatch/OptimalRedWatch Watch App/Views/ContentView.swift` - Main watch UI
- `packages/watchos/OptimalRedWatch/OptimalRedWatch Watch App/Services/HealthKitManager.swift` - HealthKit queries
- `packages/watchos/OptimalRedWatch/OptimalRedWatch Watch App/Services/WatchConnectivityManager.swift` - WC session
- `packages/watchos/OptimalRedWatch/OptimalRedWatch.xcodeproj/project.pbxproj` - Project config (HealthKit permission strings live here as INFOPLIST_KEY_ build settings)

### iPhone App
- `packages/ios/OptimalRed/OptimalRed/OptimalRedApp.swift` - App entry point
- `packages/ios/OptimalRed/OptimalRed/Views/MetricsView.swift` - Today's metrics tab
- `packages/ios/OptimalRed/OptimalRed/Views/HistoryView.swift` - History tab
- `packages/ios/OptimalRed/OptimalRed/Services/HealthKitService.swift` - HealthKit
- `packages/ios/OptimalRed/OptimalRed/Services/WatchConnectivityService.swift` - Receives from Watch
- `packages/ios/OptimalRed/OptimalRed/Persistence/SwiftDataModels.swift` - SwiftData models
- `packages/ios/OptimalRed/OptimalRed/Info.plist` - HealthKit permission strings

### Backend (Phase 1 - To Create)
- `packages/backend/app/api/health/sync/route.ts`
- `packages/backend/lib/db/schema.ts` (Drizzle)

## Apple Developer Console Setup (Required Before Building)

### 1. Register Bundle IDs (✅ COMPLETED)
In [App Store Connect](https://appstoreconnect.apple.com/):

Go to **Certificates, Identifiers & Profiles** → **Identifiers**:

1. **✅ App ID for iPhone**:
   - Type: App
   - Description: Optimal Red iOS
   - Bundle ID: `app.optimalred.ios` (Explicit)
   - Capabilities: HealthKit, Sign in with Apple, iCloud

2. **✅ App ID for Watch**:
   - Type: App
   - Description: Optimal Red watchOS
   - Bundle ID: `app.optimalred.watchos` (Explicit)
   - Capabilities: HealthKit

3. **✅ App ID for WatchKit Extension**:
   - Type: App Clip
   - Description: Optimal Red WatchKit
   - Bundle ID: `app.optimalred.watchos.watchkit` (Explicit)
   - Capabilities: HealthKit

4. **✅ App ID for macOS** (Phase 2):
   - Type: App
   - Description: Optimal Red macOS
   - Bundle ID: `app.optimalred.macos` (Explicit)
   - Capabilities: Sign in with Apple, iCloud
   - Note: No HealthKit - Mac app only reads from backend, doesn't record

### 2. Create Provisioning Profiles (NEXT)
In **Certificates, Identifiers & Profiles** → **Provisioning Profiles**:

1. **iOS Development Profile**:
   - Type: Development
   - App ID: app.optimalred.ios
   - Certificate: Select your developer cert
   - Devices: Select your test iPhone devices
   - Name: "Optimal Red iOS Dev"

2. **watchOS Development Profile**:
   - Type: Development
   - App ID: app.optimalred.watchos
   - Certificate: Select your developer cert
   - Devices: Select your test Apple Watches
   - Name: "Optimal Red watchOS Dev"

3. **WatchKit Extension Development Profile**:
   - Type: Development
   - App ID: app.optimalred.watchos.watchkit
   - Certificate: Select your developer cert
   - Devices: Select your test Apple Watches
   - Name: "Optimal Red WatchKit Dev"

4. **macOS Development Profile** (Phase 2):
   - Type: Development
   - App ID: app.optimalred.macos
   - Certificate: Select your developer cert
   - Devices: Select your test Mac devices
   - Name: "Optimal Red macOS Dev"

**Download all 4 profiles and import into Xcode**.

### 3. In Xcode (After Creating Projects)
- Set Team ID for both projects (Xcode → Preferences → Accounts → Team ID)
- Set Bundle ID to match what you registered
- Select provisioning profiles in Build Settings
- HealthKit capability will auto-enable if profile is correct

### 4. Enable HealthKit Permissions
In Xcode Info.plist for both Watch & iPhone:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Optimal Red needs access to your health data to track heart rate, distance, elevation, and calories from your Apple Watch.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Optimal Red needs permission to save your workouts to Health.</string>
```

### Checklist Before Building
- [x] Created app.optimalred.ios Bundle ID (iPhone - HealthKit, Sign in with Apple, iCloud)
- [x] Created app.optimalred.watchos Bundle ID (Watch - HealthKit)
- [x] Created app.optimalred.watchos.watchkit Bundle ID (WatchKit - HealthKit)
- [x] Created app.optimalred.macos Bundle ID (Mac - Sign in with Apple, iCloud)
- [x] Enabled HealthKit on iOS, watchOS, and WatchKit
- [x] Added HealthKit permission strings (NSHealthShareUsageDescription, NSHealthUpdateUsageDescription)
- [x] Set Team ID in Xcode projects (DEVELOPMENT_TEAM = 6XYMR8VRKR)
- [ ] Create 4 development provisioning profiles (iOS, watchOS, WatchKit, macOS)
- [ ] Download and import profiles to Xcode

## fastlane Setup

Fastlane is configured in `packages/ios/OptimalRed/fastlane/`.
All fastlane commands must be run from `packages/ios/OptimalRed/`.

### Lanes
| Command | What it does |
|---|---|
| `fastlane build` | Clean archive locally — use this to verify every change compiles and signs correctly |
| `fastlane beta` | Bump build number → build → upload to TestFlight |
| `fastlane bump_build` | Increment build number only |

### Development workflow
- **After every meaningful change**: run `fastlane build` to confirm the release build is clean (catches import errors, deprecated APIs, signing issues that the simulator misses)
- **After completing a feature or batch of changes**: run `fastlane beta` to ship a TestFlight build so it can be tested on a real device immediately
- The Watch app is bundled automatically — one `fastlane beta` ships both iPhone and Watch

### Credentials (already configured)
`packages/ios/OptimalRed/fastlane/.env.local` is set up with the App Store Connect API key.
Do not commit `.env.local` — it is gitignored.

## Running Locally (CLI – No Xcode Needed)

### Build & Run iOS App in Simulator

**Copy & paste this command from `packages/ios/OptimalRed` directory:**

```bash
fastlane build && xcodebuild -scheme OptimalRed -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build install && xcrun simctl launch booted app.optimalred.ios && sleep 2 && ps aux | grep OptimalRed | grep -v grep
```

This builds, launches in simulator, and shows the running process (PID, CPU%, memory, status).

**Expected output:**
Shows iPhone app running in simulator with process info:
```
riyaaddinath-nc  40882   0.0  2.3 435695216  376524   ??  S     9:09AM   0:01.45 /path/to/OptimalRed.app/OptimalRed
```

### Quick Commands

```bash
cd /Users/riyaaddinath-nc/Music/optimal-red/packages/ios/OptimalRed

# Build everything
fastlane build

# Upload to TestFlight
fastlane beta

# Run on simulator (after build)
xcodebuild -scheme OptimalRed -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath build install

# Kill running app
killall OptimalRed

# Check if running
ps aux | grep OptimalRed | grep -v grep
```

### macOS App (Phase 2)
When the macOS app is ready, use the same pattern as GuidanceMac:
```bash
cd /Users/riyaaddinath-nc/Music/optimal-red/packages/macos/OptimalRedMac
fastlane build && open build/OptimalRedMac.app && sleep 2 && ps aux | grep OptimalRedMac | grep -v grep
```

## Pinned UI Improvements (Next Sprint)
- [ ] Active recording: elevation gain graph as user walks (like Fitness.app)
- [ ] Active recording: per-km (or per-mile) split times
- [ ] Active recording: live heart rate graph during session
- [ ] General iPhone UI polish pass

## Next Steps

1. **Test Watch ↔ iPhone connection** (simulators)
   - Xcode auto-pairs simulators when you run the Watch scheme — it should launch the companion iPhone simulator automatically
   - If they still don't connect: run on real devices (Watch + iPhone) — WatchConnectivity is more reliable on hardware

2. **Provision real devices** (Apple Developer Console)
   - Create iOS + watchOS development provisioning profiles
   - Download and import to Xcode
   - Run on physical iPhone + Apple Watch for true end-to-end test

3. **Set Up CI/CD**
   - `.github/workflows/test-watchos.yml`
   - `.github/workflows/test-ios.yml`

4. **TestFlight beta** ✅ Build 6 live — includes Watch companion
   - Invite testers

5. **Start Phase 1** (Backend)
   - Deploy Next.js to DigitalOcean
   - Create PostgreSQL schema
   - Implement sync endpoints

## Notes

- Apple Developer identifier already registered for "Optimal Red"
- Domain ownership: Check DigitalOcean CLI for domain details
- Backend deployment target: DigitalOcean App Platform
- Ignore existing OptimalRed GitHub repo - this is a fresh start

## Bundle IDs & App Identifiers

### Registered Bundle IDs (✅ All Created)
- **iPhone App**: `app.optimalred.ios` (HealthKit, Sign in with Apple, iCloud)
- **Watch App**: `app.optimalred.watchos` (HealthKit)
- **WatchKit Extension**: `app.optimalred.watchos.watchkit` (HealthKit)
- **macOS App**: `app.optimalred.macos` (Sign in with Apple, iCloud) - Phase 2

### Backend Domain
- **API**: `api.optimalred.app`
- **Dashboard**: `dashboard.optimalred.app`

## Team Access

- **GitHub**: ShoeHorn02 (authenticated)
- **DigitalOcean**: doctl (authenticated, has credentials)
- **Namecheap**: Domain owner (optimalred.app)
- **Xcode**: Available for local development
- **fastlane**: Available (v2.236.1) for build automation

---

Last Updated: 2026-06-28 | Status: Phase 0 complete — Watch embedded in iOS project, both shipped as one IPA (Build 6 on TestFlight)

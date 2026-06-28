# Optimal Red - Apple Health Tracking Platform

## Project Overview

Optimal Red is a comprehensive health tracking application for Apple ecosystem devices. It captures health metrics (heart rate, distance, elevation, calories) from an Apple Watch, syncs to iPhone, and eventually displays data on Mac and web dashboards.

**Vision**: Create the macOS app that Apple Fitness+ doesn't have, with deep HealthKit integration across watch, phone, and Mac.

## Current Status

**Phase**: Phase 0 (MVP) - Initialize monorepo & create Watch + iPhone apps
**Date Started**: 2026-06-27
**GitHub**: https://github.com/ShoeHorn02/optimal-red

### What's Done
- [x] Monorepo structure created (packages: shared, watchos, ios, macos, backend)
- [x] Shared types package initialized (health metrics, user models)
- [x] Backend package template created (Next.js + Drizzle)
- [x] GitHub repository created
- [ ] Watch app created (In Progress)
- [ ] iPhone app created (In Progress)
- [ ] CI/CD workflows set up
- [ ] Backend database schema

## Architecture

### Monorepo Structure
```
optimal-red/
├── packages/
│   ├── shared/           ← Shared types (HealthMetric, User, sync protocol)
│   ├── watchos/          ← Watch app (records metrics via HealthKit)
│   ├── ios/              ← iPhone app (hub: storage + sync engine)
│   ├── macos/            ← Mac app (Phase 2)
│   └── backend/          ← Next.js backend (Phase 1)
├── .github/workflows/    ← CI/CD
└── CLAUDE.md
```

### Data Flow
```
Apple Watch (HealthKit)
  ↓ [WatchConnectivity]
iPhone (SwiftData hub, sync engine)
  ↓ [HTTPS - Phase 1]
Backend (PostgreSQL)
  ↓
Mac + Web Dashboard
```

### Technology Stack
- **Watch OS**: SwiftUI + HealthKit (native sensors)
- **iOS**: SwiftUI + SwiftData (local persistence)
- **macOS**: SwiftUI (Phase 2)
- **Backend**: Next.js 16 + TypeScript + Drizzle ORM + PostgreSQL
- **Cloud**: DigitalOcean (App Platform + Managed PostgreSQL)
- **IPC**: WatchConnectivity framework
- **Auth**: Apple Sign-in (Phase 1)

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

### Watch App (To Create)
- `packages/watchos/OptimalRedWatch/OptimalRedWatchApp.swift`
- `packages/watchos/OptimalRedWatch/Views/MetricsView.swift`
- `packages/watchos/OptimalRedWatch/Services/HealthKitService.swift`
- `packages/watchos/OptimalRedWatch/Services/WatchConnectivityService.swift`

### iPhone App (To Create)
- `packages/ios/OptimalRed/OptimalRedApp.swift`
- `packages/ios/OptimalRed/Views/MetricsView.swift`
- `packages/ios/OptimalRed/Views/HistoryView.swift`
- `packages/ios/OptimalRed/Services/HealthKitService.swift`
- `packages/ios/OptimalRed/Services/WatchConnectivityService.swift`
- `packages/ios/OptimalRed/Persistence/SwiftDataModels.swift`

### Backend (To Create)
- `packages/backend/app/api/health/sync/route.ts`
- `packages/backend/lib/db/schema.ts` (Drizzle)

## Next Steps

1. **Create Watch App** (Xcode)
   - New watchOS project
   - HealthKit permissions
   - Read HR, distance, elevation, calories
   - Display on Watch face

2. **Create iPhone App** (Xcode)
   - New iOS project
   - WatchConnectivity receiver
   - SwiftData models
   - Display metrics list + history

3. **Set Up CI/CD**
   - `.github/workflows/test-watchos.yml`
   - `.github/workflows/test-ios.yml`

4. **Test MVP** (TestFlight)
   - Watch sends metrics
   - iPhone receives & displays
   - Works offline

5. **Start Phase 1** (Backend)
   - Deploy Next.js to DigitalOcean
   - Create PostgreSQL schema
   - Implement sync endpoints

## Notes

- Apple Developer identifier already registered for "Optimal Red"
- Domain ownership: Check DigitalOcean CLI for domain details
- Backend deployment target: DigitalOcean App Platform
- Ignore existing OptimalRed GitHub repo - this is a fresh start

## Team Access

- **GitHub**: ShoeHorn02 (authenticated)
- **DigitalOcean**: doctl (authenticated, has credentials)
- **Xcode**: Available for local development
- **fastlane**: Available (v2.236.1) for build automation

---

Last Updated: 2026-06-27 | Status: Phase 0 Initialization

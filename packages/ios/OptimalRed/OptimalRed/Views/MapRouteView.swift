import SwiftUI
import MapKit
import HealthKit
import Charts

// Activity types that record GPS routes
private let gpsActivityTypes: Set<HKWorkoutActivityType> = [
  .hiking, .walking, .running, .cycling,
  .crossCountrySkiing, .downhillSkiing, .snowboarding, .skatingSports,
  .paddleSports, .rowing, .surfingSports, .waterFitness
]

struct MapRouteView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
  @State private var showingDetail = false

  private var gpsWorkouts: [HKWorkout] {
    healthKitManager.recentWorkouts.filter { gpsActivityTypes.contains($0.workoutActivityType) }
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      map.ignoresSafeArea()

      VStack(spacing: 0) {
        // Active workout stats strip
        if let workout = healthKitManager.selectedWorkout {
          statsStrip(for: workout)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }

        // Horizontal scrolling workout list
        workoutList
      }
    }
    .sheet(isPresented: $showingDetail) {
      if let workout = healthKitManager.selectedWorkout {
        WorkoutDetailSheet(workout: workout)
          .environmentObject(healthKitManager)
      }
    }
    .onAppear {
      if healthKitManager.recentWorkouts.isEmpty {
        healthKitManager.fetchRecentWorkouts()
      } else if gpsWorkouts.count < 3 && healthKitManager.hasMoreWorkouts {
        healthKitManager.fetchMoreWorkouts()
      }
    }
    .onChange(of: healthKitManager.routeCoordinates.count) { _, _ in
      fitToRoute(healthKitManager.routeCoordinates)
    }
  }

  // MARK: - Map

  private var map: some View {
    ZStack {
      Map(position: $position) {
        UserAnnotation()
        if let start = healthKitManager.routeCoordinates.first {
          Annotation("", coordinate: start, anchor: .bottom) { startPin }
        }
        if let end = healthKitManager.routeCoordinates.last,
           healthKitManager.routeCoordinates.count > 1 {
          Annotation("", coordinate: end, anchor: .bottom) { finishPin }
        }
        if !healthKitManager.routeCoordinates.isEmpty {
          MapPolyline(coordinates: healthKitManager.routeCoordinates)
            .stroke(.red, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
      }
      .mapStyle(.hybrid(elevation: .realistic))
      .mapControls {
        MapUserLocationButton()
        MapCompass()
      }

      // Route loading spinner
      if healthKitManager.isLoadingRoute {
        ProgressView("Loading route…")
          .padding(14)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
      }

      // No workouts with GPS yet
      if gpsWorkouts.isEmpty && !healthKitManager.isFetchingWorkouts {
        VStack(spacing: 8) {
          Image(systemName: "map.slash")
            .font(.system(size: 28))
            .foregroundStyle(.secondary)
          Text("No GPS workouts found")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
      }
    }
  }

  // MARK: - Pins

  private var startPin: some View {
    ZStack {
      Circle().fill(.green).frame(width: 24, height: 24).shadow(radius: 3)
      Image(systemName: "flag.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
    }
  }

  private var finishPin: some View {
    ZStack {
      Circle().fill(.red).frame(width: 24, height: 24).shadow(radius: 3)
      Image(systemName: "flag.checkered").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
    }
  }

  // MARK: - Stats strip

  private func statsStrip(for workout: HKWorkout) -> some View {
    Button { showingDetail = true } label: {
      HStack(spacing: 0) {
        statCell(
          value: String(format: "%.2f", (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000),
          unit: "km", icon: "figure.walk", color: .blue
        )
        Divider().frame(height: 40)
        statCell(
          value: String(format: "%.0f", healthKitManager.routeElevationGain),
          unit: "m↑", icon: "mountain.2.fill", color: .green
        )
        Divider().frame(height: 40)
        statCell(
          value: formatDuration(workout.duration),
          unit: "", icon: "timer", color: .orange
        )
        Divider().frame(height: 40)
        statCell(
          value: String(format: "%.0f", workout.statistics(
            for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
          )?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0),
          unit: "kcal", icon: "flame.fill", color: .red
        )
        Image(systemName: "chevron.up")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.trailing, 14)
      }
      .padding(.vertical, 10)
      .background(.ultraThinMaterial)
    }
    .buttonStyle(.plain)
  }

  private func statCell(value: String, unit: String, icon: String, color: Color) -> some View {
    VStack(spacing: 2) {
      Image(systemName: icon).font(.caption2).foregroundStyle(color)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(value).font(.subheadline.weight(.bold))
        if !unit.isEmpty { Text(unit).font(.caption2).foregroundStyle(.secondary) }
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Workout list

  private var workoutList: some View {
    VStack(spacing: 0) {
      if gpsWorkouts.isEmpty && !healthKitManager.isFetchingWorkouts {
        emptyState
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(gpsWorkouts, id: \.uuid) { workout in
              WorkoutChip(
                workout: workout,
                isSelected: healthKitManager.selectedWorkout?.uuid == workout.uuid
              )
              .onTapGesture { healthKitManager.selectWorkout(workout) }
              .onAppear {
                if workout.uuid == gpsWorkouts.last?.uuid {
                  healthKitManager.fetchMoreWorkouts()
                }
              }
            }
            if healthKitManager.isFetchingWorkouts {
              ProgressView().padding(.horizontal, 12)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
      }
    }
  }

  // MARK: - Empty / Loading

  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "figure.walk.circle").font(.system(size: 36)).foregroundStyle(.quaternary)
      Text("No workouts yet").font(.subheadline).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(.ultraThinMaterial)
  }

  // MARK: - Helpers

  private func fitToRoute(_ coords: [CLLocationCoordinate2D]) {
    guard coords.count > 1 else { return }
    let lats = coords.map(\.latitude)
    let lngs = coords.map(\.longitude)
    let center = CLLocationCoordinate2D(
      latitude: (lats.min()! + lats.max()!) / 2,
      longitude: (lngs.min()! + lngs.max()!) / 2
    )
    let span = MKCoordinateSpan(
      latitudeDelta: max((lats.max()! - lats.min()!) * 1.6, 0.005),
      longitudeDelta: max((lngs.max()! - lngs.min()!) * 1.6, 0.005)
    )
    withAnimation { position = .region(MKCoordinateRegion(center: center, span: span)) }
  }

  private func formatDuration(_ s: TimeInterval) -> String {
    let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
  }
}

// MARK: - Workout Chip

struct WorkoutChip: View {
  let workout: HKWorkout
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 5) {
        Image(systemName: activityIcon)
          .font(.caption.weight(.semibold))
          .foregroundStyle(isSelected ? .white : .primary)
        Text(workoutDate)
          .font(.caption.weight(.semibold))
          .foregroundStyle(isSelected ? .white : .primary)
      }
      Text(subtitle)
        .font(.caption2)
        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
    }
    .padding(.horizontal, 12).padding(.vertical, 8)
    .background(isSelected ? Color.red : Color.secondary.opacity(0.15),
                in: RoundedRectangle(cornerRadius: 12))
    .animation(.easeInOut(duration: 0.15), value: isSelected)
  }

  private var subtitle: String {
    let dist = (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000
    if dist > 0 { return String(format: "%.1f km", dist) }
    let dur = workout.duration
    let m = Int(dur) / 60
    return "\(m) min"
  }

  var activityIcon: String {
    switch workout.workoutActivityType {
    case .hiking:                       return "figure.hiking"
    case .running:                      return "figure.run"
    case .cycling:                      return "figure.outdoor.cycle"
    case .swimming:                     return "figure.pool.swim"
    case .traditionalStrengthTraining,
         .functionalStrengthTraining:   return "dumbbell.fill"
    case .yoga:                         return "figure.yoga"
    case .dance:                        return "figure.dance"
    case .rowing:                       return "figure.rowing"
    case .elliptical:                   return "figure.elliptical"
    case .stairClimbing:                return "figure.stair.stepper"
    case .pilates:                      return "figure.pilates"
    case .mindAndBody:                  return "brain.head.profile"
    case .soccer:                       return "soccerball"
    case .tennis:                       return "tennisball.fill"
    case .basketball:                   return "basketball.fill"
    default:                            return "figure.walk"
    }
  }

  private var workoutDate: String {
    let cal = Calendar.current
    if cal.isDateInToday(workout.startDate)     { return "Today" }
    if cal.isDateInYesterday(workout.startDate) { return "Yesterday" }
    return workout.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
  }
}

// MARK: - Workout Detail Sheet (dark Fitness-style)

private let detailCardBg  = Color(white: 0.13)
private let detailGreen   = Color(red: 0.60, green: 0.95, blue: 0.13)
private let detailIconBg  = Color(red: 0.13, green: 0.22, blue: 0.10)
private let detailYellow  = Color(red: 1.0,  green: 0.85, blue: 0.0)
private let detailPink    = Color(red: 0.95, green: 0.35, blue: 0.45)
private let detailOrange  = Color(red: 1.0,  green: 0.50, blue: 0.25)

struct WorkoutDetailSheet: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  let workout: HKWorkout
  @Environment(\.dismiss) private var dismiss
  @State private var hrSamples: [(Date, Double)] = []

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            headerSection
            workoutDetailsCard
            if !hrSamples.isEmpty    { heartRateSection }
            if !healthKitManager.elevationProfile.isEmpty { elevationSection }
            if !healthKitManager.kmSplits.isEmpty         { splitsSection }
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 32)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(workout.startDate.formatted(.dateTime.weekday(.wide).month().day()))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .foregroundStyle(detailGreen)
        }
      }
      .toolbarBackground(.black, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
    }
    .preferredColorScheme(.dark)
    .onAppear {
      healthKitManager.fetchHeartRateSamples(for: workout) { hrSamples = $0 }
    }
  }

  // MARK: - Header

  private var headerSection: some View {
    HStack(spacing: 16) {
      ZStack {
        Circle().fill(detailIconBg).frame(width: 64, height: 64)
        Image(systemName: activityIcon)
          .font(.system(size: 28, weight: .medium))
          .foregroundStyle(detailGreen)
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(workout.workoutActivityType.displayName)
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(.white)
        Text("\(workout.startDate.formatted(.dateTime.hour().minute())) – \(workout.endDate.formatted(.dateTime.hour().minute()))")
          .font(.subheadline)
          .foregroundStyle(Color(white: 0.55))
        Text(workout.sourceRevision.source.name)
          .font(.caption)
          .foregroundStyle(Color(white: 0.40))
      }
    }
    .padding(.top, 8)
  }

  // MARK: - Workout Details 2×2 card

  private var workoutDetailsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("Workout Details")

      VStack(spacing: 0) {
        HStack(spacing: 0) {
          detailCell(label: "Workout Time",    value: formatDuration(workout.duration),    color: detailYellow)
          Divider().frame(width: 0.5).background(Color(white: 0.25))
          detailCell(label: "Active Calories", value: "\(Int(activeCal))CAL",              color: detailPink)
        }
        Divider().background(Color(white: 0.25))
        HStack(spacing: 0) {
          detailCell(label: "Total Calories",  value: "\(Int(totalCal))CAL",               color: detailPink)
          Divider().frame(width: 0.5).background(Color(white: 0.25))
          detailCell(label: "Avg. Heart Rate", value: avgHR > 0 ? "\(Int(avgHR))BPM" : "–", color: detailOrange)
        }
        // Distance + pace row (only for distance-based workouts)
        if distanceKm > 0 {
          Divider().background(Color(white: 0.25))
          HStack(spacing: 0) {
            detailCell(label: "Distance", value: String(format: "%.2fKM", distanceKm), color: detailGreen)
            Divider().frame(width: 0.5).background(Color(white: 0.25))
            if elevGain > 0 {
              detailCell(label: "Elevation Gain", value: String(format: "%.0fm", elevGain), color: detailGreen)
            } else {
              detailCell(label: "Avg. Pace", value: paceString(workout.duration / max(1, distanceKm)), color: detailGreen)
            }
          }
        }
      }
      .background(detailCardBg, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  private func detailCell(label: String, value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.caption).foregroundStyle(Color(white: 0.55))
      Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
  }

  // MARK: - Heart Rate chart

  private var heartRateSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader("Heart Rate")

      VStack(alignment: .leading, spacing: 6) {
        Chart {
          ForEach(Array(hrSamples.enumerated()), id: \.offset) { i, pt in
            BarMark(x: .value("t", i), y: .value("BPM", pt.1))
              .foregroundStyle(
                LinearGradient(colors: [Color(red:1,green:0.2,blue:0.2), Color(red:0.8,green:0.1,blue:0.1)],
                               startPoint: .top, endPoint: .bottom)
              )
              .cornerRadius(2)
          }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
          AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { v in
            AxisGridLine().foregroundStyle(Color(white: 0.2))
            AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))").font(.caption2).foregroundStyle(Color(white: 0.4)) } }
          }
        }
        .chartYScale(domain: (hrSamples.map(\.1).min() ?? 0) - 5 ... (hrSamples.map(\.1).max() ?? 200) + 5)
        .frame(height: 130)

        // Time labels
        HStack {
          Text(workout.startDate.formatted(.dateTime.hour().minute()))
            .font(.caption2).foregroundStyle(Color(white: 0.4))
          Spacer()
          Text(workout.endDate.formatted(.dateTime.hour().minute()))
            .font(.caption2).foregroundStyle(Color(white: 0.4))
        }

        if avgHR > 0 {
          Text(String(format: "%.0f BPM AVG", avgHR))
            .font(.caption.weight(.semibold))
            .foregroundStyle(detailOrange)
        }
      }
      .padding(16)
      .background(detailCardBg, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  // MARK: - Elevation

  private var elevationSection: some View {
    let profile = healthKitManager.elevationProfile
    let minAlt  = profile.min() ?? 0
    let maxAlt  = profile.max() ?? 0

    return VStack(alignment: .leading, spacing: 12) {
      sectionHeader("Elevation")

      VStack(alignment: .leading, spacing: 8) {
        Chart {
          ForEach(Array(profile.enumerated()), id: \.offset) { i, alt in
            AreaMark(x: .value("p", i), yStart: .value("base", minAlt), yEnd: .value("alt", alt))
              .foregroundStyle(detailGreen.opacity(0.25))
            LineMark(x: .value("p", i), y: .value("alt", alt))
              .foregroundStyle(detailGreen)
              .lineStyle(StrokeStyle(lineWidth: 2))
          }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
          AxisMarks(values: .automatic(desiredCount: 3)) { v in
            AxisGridLine().foregroundStyle(Color(white: 0.2))
            AxisValueLabel { if let d = v.as(Double.self) { Text(String(format: "%.0fm", d)).font(.caption2).foregroundStyle(Color(white: 0.4)) } }
          }
        }
        .chartYScale(domain: max(0, minAlt - 10)...maxAlt + 10)
        .frame(height: 120)

        HStack {
          Text(String(format: "Low: %.0f m", minAlt)).font(.caption2).foregroundStyle(Color(white: 0.4))
          Spacer()
          if healthKitManager.routeElevationGain > 0 {
            Text(String(format: "+%.0f m gain", healthKitManager.routeElevationGain))
              .font(.caption2.weight(.semibold)).foregroundStyle(detailGreen)
          }
          Spacer()
          Text(String(format: "High: %.0f m", maxAlt)).font(.caption2).foregroundStyle(Color(white: 0.4))
        }
      }
      .padding(16)
      .background(detailCardBg, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  // MARK: - Splits

  private var splitsSection: some View {
    let splits  = healthKitManager.kmSplits
    let best    = splits.map(\.paceSeconds).min() ?? 1
    let worst   = splits.map(\.paceSeconds).max() ?? 1

    return VStack(alignment: .leading, spacing: 12) {
      sectionHeader("Splits")

      VStack(spacing: 10) {
        ForEach(splits) { split in
          HStack(spacing: 10) {
            Text("km \(split.number)")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(Color(white: 0.45))
              .frame(width: 46, alignment: .leading)

            GeometryReader { geo in
              ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color(white: 0.2)).frame(height: 6)
                let ratio = worst > best ? (1 - (split.paceSeconds - best) / max(1, worst - best)) : 1.0
                RoundedRectangle(cornerRadius: 3)
                  .fill(paceBarColor(split.paceSeconds, best: best, worst: worst))
                  .frame(width: geo.size.width * ratio, height: 6)
              }
            }
            .frame(height: 6)

            Text(split.paceString)
              .font(.subheadline.weight(.semibold).monospacedDigit())
              .foregroundStyle(.white)
              .frame(width: 72, alignment: .trailing)
          }
        }
      }
      .padding(16)
      .background(detailCardBg, in: RoundedRectangle(cornerRadius: 14))
    }
  }

  private func paceBarColor(_ pace: Double, best: Double, worst: Double) -> Color {
    let ratio = (pace - best) / max(1, worst - best)
    return ratio < 0.33 ? detailGreen : ratio < 0.66 ? .yellow : .orange
  }

  // MARK: - Section header

  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 18, weight: .bold))
      .foregroundStyle(.white)
  }

  // MARK: - Computed helpers

  private var activeCal: Double {
    workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)?
      .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
  }
  private var totalCal: Double {
    let basal = workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!)?
      .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    return activeCal + basal
  }
  private var avgHR: Double {
    workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)?
      .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? 0
  }
  private var distanceKm: Double {
    (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000
  }
  private var elevGain: Double { healthKitManager.routeElevationGain }

  var activityIcon: String {
    switch workout.workoutActivityType {
    case .hiking:   return "figure.hiking"
    case .running:  return "figure.run"
    case .cycling:  return "figure.outdoor.cycle"
    case .swimming: return "figure.pool.swim"
    case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
    case .yoga:     return "figure.yoga"
    case .dance:    return "figure.dance"
    case .rowing:   return "figure.rowing"
    case .elliptical: return "figure.elliptical"
    case .stairClimbing: return "figure.stair.stepper"
    case .pilates:  return "figure.pilates"
    case .mindAndBody: return "brain.head.profile"
    default:        return "figure.walk"
    }
  }

  private func formatDuration(_ s: TimeInterval) -> String {
    let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60; let sec = Int(s) % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
  }

  private func paceString(_ secsPerKm: TimeInterval) -> String {
    let m = Int(secsPerKm) / 60; let s = Int(secsPerKm) % 60
    return String(format: "%d:%02d /km", m, s)
  }
}

#Preview {
  MapRouteView().environmentObject(HealthKitManager())
}

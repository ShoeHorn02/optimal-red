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

// MARK: - Workout Detail Sheet

struct WorkoutDetailSheet: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  let workout: HKWorkout
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          headerStats
          if !healthKitManager.elevationProfile.isEmpty {
            elevationChart
          }
          if !healthKitManager.kmSplits.isEmpty {
            splitsSection
          }
          metaSection
        }
        .padding()
      }
      .navigationTitle(workoutTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  // MARK: - Header stats grid

  private var headerStats: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      statCard(icon: "figure.walk",     color: .blue,   label: "Distance",
               value: String(format: "%.2f", (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000),
               unit: "km")
      statCard(icon: "timer",           color: .orange,  label: "Duration",
               value: formatDuration(workout.duration), unit: "")
      statCard(icon: "mountain.2.fill", color: .green,  label: "Elevation Gain",
               value: String(format: "%.0f", healthKitManager.routeElevationGain), unit: "m")
      statCard(icon: "flame.fill",      color: .red,    label: "Calories",
               value: String(format: "%.0f", workout.statistics(
                for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
               )?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0),
               unit: "kcal")
      if let avgHR = averageHR {
        statCard(icon: "heart.fill", color: .red, label: "Avg Heart Rate",
                 value: String(format: "%.0f", avgHR), unit: "BPM")
      }
      if workout.duration > 0 {
        let pace = workout.duration / max(1, (workout.totalDistance?.doubleValue(for: .meter()) ?? 1) / 1000)
        statCard(icon: "speedometer", color: .purple, label: "Avg Pace",
                 value: paceString(pace), unit: "/km")
      }
    }
  }

  private func statCard(icon: String, color: Color, label: String, value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(label, systemImage: icon)
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text(value).font(.title2.weight(.bold))
        if !unit.isEmpty { Text(unit).font(.caption).foregroundStyle(.secondary) }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Elevation chart

  private var elevationChart: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Elevation").font(.headline)
      let profile = healthKitManager.elevationProfile
      let minAlt  = (profile.min() ?? 0)
      let maxAlt  = (profile.max() ?? 0)
      Chart {
        ForEach(Array(profile.enumerated()), id: \.offset) { i, alt in
          AreaMark(
            x: .value("Point", i),
            yStart: .value("Base", minAlt),
            yEnd:   .value("Alt",  alt)
          )
          .foregroundStyle(.green.opacity(0.3))
          LineMark(x: .value("Point", i), y: .value("Alt", alt))
            .foregroundStyle(.green)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
      }
      .chartXAxis(.hidden)
      .chartYAxis {
        AxisMarks(values: .automatic(desiredCount: 4)) { value in
          AxisGridLine()
          AxisValueLabel {
            if let d = value.as(Double.self) {
              Text(String(format: "%.0f m", d)).font(.caption2)
            }
          }
        }
      }
      .chartYScale(domain: max(0, minAlt - 10)...maxAlt + 10)
      .frame(height: 140)

      HStack {
        Text(String(format: "Low: %.0f m", minAlt)).font(.caption2).foregroundStyle(.secondary)
        Spacer()
        Text(String(format: "High: %.0f m", maxAlt)).font(.caption2).foregroundStyle(.secondary)
      }
    }
    .padding(14)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Splits

  private var splitsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Splits").font(.headline)
      ForEach(healthKitManager.kmSplits) { split in
        HStack {
          Text("km \(split.number)")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 50, alignment: .leading)
          paceBar(pace: split.paceSeconds, worst: healthKitManager.kmSplits.map(\.paceSeconds).max() ?? 1)
          Text(split.paceString)
            .font(.subheadline.monospacedDigit())
            .frame(width: 70, alignment: .trailing)
        }
      }
    }
    .padding(14)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
  }

  private func paceBar(pace: Double, worst: Double) -> some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)).frame(height: 8)
        RoundedRectangle(cornerRadius: 4)
          .fill(paceColor(pace: pace, worst: worst))
          .frame(width: geo.size.width * (1 - ((pace - healthKitManager.kmSplits.map(\.paceSeconds).min()!) /
            max(1, worst - (healthKitManager.kmSplits.map(\.paceSeconds).min()!)))), height: 8)
      }
    }
    .frame(height: 8)
  }

  private func paceColor(pace: Double, worst: Double) -> Color {
    let best = healthKitManager.kmSplits.map(\.paceSeconds).min() ?? pace
    let ratio = (pace - best) / max(1, worst - best)
    return ratio < 0.33 ? .green : ratio < 0.66 ? .orange : .red
  }

  // MARK: - Meta

  private var metaSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Info").font(.headline)
      LabeledContent("Source", value: workout.sourceRevision.source.name)
      LabeledContent("Started", value: workout.startDate.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
      LabeledContent("Ended",   value: workout.endDate.formatted(.dateTime.hour().minute()))
    }
    .padding(14)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
  }

  // MARK: - Helpers

  private var workoutTitle: String {
    workout.workoutActivityType.displayName + " · " +
    workout.startDate.formatted(.dateTime.month(.abbreviated).day())
  }

  private var averageHR: Double? {
    workout.statistics(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)?
      .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
  }

  private func formatDuration(_ s: TimeInterval) -> String {
    let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
  }

  private func paceString(_ secsPerKm: TimeInterval) -> String {
    let m = Int(secsPerKm) / 60; let s = Int(secsPerKm) % 60
    return String(format: "%d:%02d", m, s)
  }
}

#Preview {
  MapRouteView().environmentObject(HealthKitManager())
}

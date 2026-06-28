import SwiftUI
import MapKit
import HealthKit

struct MapRouteView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        map

        VStack(spacing: 0) {
          if !healthKitManager.recentWorkouts.isEmpty {
            workoutPicker
          }
          if let workout = healthKitManager.selectedWorkout {
            statsCard(for: workout)
          }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
      }
      .navigationTitle("Your Hike")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarButtons }
      .overlay {
        if healthKitManager.recentWorkouts.isEmpty && !healthKitManager.isLoadingRoute {
          emptyState
        }
        if healthKitManager.isLoadingRoute {
          loadingOverlay
        }
      }
      .onAppear {
        healthKitManager.fetchRecentWorkouts()
      }
      .onChange(of: healthKitManager.routeCoordinates) { _, coords in
        fitToRoute(coords)
      }
    }
  }

  // MARK: - Map

  private var map: some View {
    Map(position: $position) {
      UserAnnotation()

      if let start = healthKitManager.routeCoordinates.first {
        Annotation("Start", coordinate: start, anchor: .bottom) {
          startMarker
        }
      }

      if let end = healthKitManager.routeCoordinates.last,
         healthKitManager.routeCoordinates.count > 1 {
        Annotation("Finish", coordinate: end, anchor: .bottom) {
          finishMarker
        }
      }

      if !healthKitManager.routeCoordinates.isEmpty {
        MapPolyline(coordinates: healthKitManager.routeCoordinates)
          .stroke(.red, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
      }
    }
    .mapStyle(.hybrid(elevation: .realistic))
    .ignoresSafeArea(edges: .top)
  }

  // MARK: - Markers

  private var startMarker: some View {
    ZStack {
      Circle()
        .fill(.green)
        .frame(width: 22, height: 22)
        .shadow(radius: 3)
      Image(systemName: "figure.hiking")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(.white)
    }
  }

  private var finishMarker: some View {
    ZStack {
      Circle()
        .fill(.red)
        .frame(width: 22, height: 22)
        .shadow(radius: 3)
      Image(systemName: "flag.checkered")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
    }
  }

  // MARK: - Workout Picker

  private var workoutPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(healthKitManager.recentWorkouts, id: \.uuid) { workout in
          WorkoutChip(
            workout: workout,
            isSelected: healthKitManager.selectedWorkout?.uuid == workout.uuid
          )
          .onTapGesture {
            healthKitManager.selectWorkout(workout)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }

  // MARK: - Stats Card

  private func statsCard(for workout: HKWorkout) -> some View {
    HStack(spacing: 0) {
      statCell(
        value: String(format: "%.2f", (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000),
        unit: "km",
        label: "Distance",
        icon: "figure.hiking",
        color: .blue
      )
      Divider().frame(height: 44)
      statCell(
        value: String(format: "%.0f", healthKitManager.routeElevationGain),
        unit: "m",
        label: "Gained",
        icon: "mountain.2.fill",
        color: .green
      )
      Divider().frame(height: 44)
      statCell(
        value: formatDuration(workout.duration),
        unit: "",
        label: "Duration",
        icon: "timer",
        color: .orange
      )
      Divider().frame(height: 44)
      statCell(
        value: String(format: "%.0f", workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0),
        unit: "kcal",
        label: "Calories",
        icon: "flame.fill",
        color: .red
      )
    }
    .padding(.bottom, 4)
  }

  private func statCell(value: String, unit: String, label: String, icon: String, color: Color) -> some View {
    VStack(spacing: 3) {
      Image(systemName: icon)
        .font(.caption)
        .foregroundStyle(color)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(value)
          .font(.subheadline.weight(.bold))
        if !unit.isEmpty {
          Text(unit)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
  }

  // MARK: - Empty & Loading

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "figure.hiking")
        .font(.system(size: 52))
        .foregroundStyle(.quaternary)
      Text("No hikes recorded")
        .font(.headline)
      Text("Start an outdoor walk or hike on your Apple Watch and the route will appear here.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 48)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.ultraThinMaterial)
  }

  private var loadingOverlay: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("Loading route…")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(20)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder
  private var toolbarButtons: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Button {
        if let coords = Optional(healthKitManager.routeCoordinates), !coords.isEmpty {
          fitToRoute(coords)
        } else {
          position = .userLocation(fallback: .automatic)
        }
      } label: {
        Image(systemName: "scope")
      }
    }
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
    withAnimation {
      position = .region(MKCoordinateRegion(center: center, span: span))
    }
  }

  private func formatDuration(_ seconds: TimeInterval) -> String {
    let h = Int(seconds) / 3600
    let m = (Int(seconds) % 3600) / 60
    return h > 0 ? "\(h)h \(m)m" : "\(m)m"
  }
}

// MARK: - Workout Chip

struct WorkoutChip: View {
  let workout: HKWorkout
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        Image(systemName: activityIcon)
          .font(.caption.weight(.semibold))
          .foregroundStyle(isSelected ? .white : .primary)
        Text(workoutDate)
          .font(.caption.weight(.semibold))
          .foregroundStyle(isSelected ? .white : .primary)
      }
      Text(String(format: "%.1f km", (workout.totalDistance?.doubleValue(for: .meter()) ?? 0) / 1000))
        .font(.caption2)
        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(isSelected ? Color.red : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    .animation(.easeInOut(duration: 0.15), value: isSelected)
  }

  private var activityIcon: String {
    switch workout.workoutActivityType {
    case .hiking:  return "figure.hiking"
    case .running: return "figure.run"
    default:       return "figure.walk"
    }
  }

  private var workoutDate: String {
    let cal = Calendar.current
    if cal.isDateInToday(workout.startDate)     { return "Today" }
    if cal.isDateInYesterday(workout.startDate) { return "Yesterday" }
    return workout.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
  }
}

#Preview {
  MapRouteView()
    .environmentObject(HealthKitManager())
}

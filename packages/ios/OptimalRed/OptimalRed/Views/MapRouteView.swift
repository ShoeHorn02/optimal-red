import SwiftUI
import MapKit

struct MapRouteView: View {
  @EnvironmentObject var healthKitManager: HealthKitManager
  @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        Map(position: $position) {
          UserAnnotation()
          if !healthKitManager.routeCoordinates.isEmpty {
            MapPolyline(coordinates: healthKitManager.routeCoordinates)
              .stroke(.red, lineWidth: 4)
          }
        }
        .mapStyle(.standard(elevation: .realistic))
        .ignoresSafeArea(edges: .bottom)

        if healthKitManager.distance > 0 || healthKitManager.elevation > 0 {
          routeStatsOverlay
        }
      }
      .navigationTitle("Activity Map")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            position = .userLocation(fallback: .automatic)
            healthKitManager.fetchTodayWorkoutRoute()
          } label: {
            Image(systemName: "location.fill")
          }
        }
      }
      .onAppear {
        healthKitManager.fetchTodayWorkoutRoute()
      }
    }
  }

  private var routeStatsOverlay: some View {
    HStack(spacing: 0) {
      RouteStatCell(value: String(format: "%.2f", healthKitManager.distance), unit: "km",  label: "Distance",  icon: "figure.walk",     color: .blue)
      Divider().frame(height: 44)
      RouteStatCell(value: String(format: "%.0f", healthKitManager.elevation), unit: "m",   label: "Elevation", icon: "mountain.2.fill", color: .green)
      Divider().frame(height: 44)
      RouteStatCell(value: String(format: "%.0f", healthKitManager.calories),  unit: "kcal",label: "Calories",  icon: "flame.fill",      color: .orange)
    }
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal)
    .padding(.bottom, 8)
  }
}

struct RouteStatCell: View {
  let value: String
  let unit: String
  let label: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(spacing: 3) {
      Image(systemName: icon)
        .font(.caption)
        .foregroundStyle(color)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(value)
          .font(.headline.weight(.semibold))
        Text(unit)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
  }
}

#Preview {
  MapRouteView()
    .environmentObject(HealthKitManager())
}

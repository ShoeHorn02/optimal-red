import SwiftUI
import SwiftData

struct HistoryView: View {
  @Query(sort: \StoredHealthMetric.recordedAt, order: .reverse) var metrics: [StoredHealthMetric]

  private var groupedByDay: [(Date, [StoredHealthMetric])] {
    let calendar = Calendar.current
    let dict = Dictionary(grouping: metrics) { calendar.startOfDay(for: $0.recordedAt) }
    return dict.sorted { $0.key > $1.key }
  }

  var body: some View {
    NavigationStack {
      Group {
        if metrics.isEmpty {
          emptyState
        } else {
          List {
            ForEach(groupedByDay, id: \.0) { date, dayMetrics in
              Section {
                ForEach(dayMetrics) { metric in
                  MetricRow(metric: metric)
                }
              } header: {
                Text(date, style: .date)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.primary)
                  .textCase(nil)
              }
            }
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle("History")
    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "chart.bar.xaxis")
        .font(.system(size: 52))
        .foregroundStyle(.quaternary)
      Text("No activity yet")
        .font(.headline)
      Text("Your health metrics will appear here once your Apple Watch starts syncing.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct MetricRow: View {
  let metric: StoredHealthMetric

  private var config: (icon: String, color: Color, label: String) {
    switch metric.type {
    case "heart_rate": return ("heart.fill",       .red,    "Heart Rate")
    case "distance":   return ("figure.walk",      .blue,   "Distance")
    case "elevation":  return ("mountain.2.fill",  .green,  "Elevation")
    case "calories":   return ("flame.fill",       .orange, "Calories")
    default:           return ("circle.fill",      .gray,   metric.type.replacingOccurrences(of: "_", with: " ").capitalized)
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: config.icon)
        .font(.callout)
        .foregroundStyle(config.color)
        .frame(width: 32, height: 32)
        .background(config.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

      VStack(alignment: .leading, spacing: 2) {
        Text(config.label)
          .font(.subheadline.weight(.medium))
        Text(metric.source == "watchos" ? "Apple Watch" : "iPhone")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(String(format: "%.1f", metric.value))
            .font(.subheadline.weight(.semibold))
          Text(metric.unit)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Text(metric.recordedAt, style: .time)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
  }
}

#Preview {
  HistoryView()
    .modelContainer(for: StoredHealthMetric.self, inMemory: true)
}

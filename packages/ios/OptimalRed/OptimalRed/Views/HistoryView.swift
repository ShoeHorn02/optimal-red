import SwiftUI
import SwiftData

struct HistoryView: View {
  @Query(sort: \StoredHealthMetric.recordedAt, order: .reverse) var metrics: [StoredHealthMetric]

  var body: some View {
    NavigationStack {
      Group {
        if metrics.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
              .font(.system(size: 48))
              .foregroundColor(.gray)
            Text("No metrics yet")
              .font(.headline)
            Text("Start recording to see your history")
              .font(.caption)
              .foregroundColor(.gray)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
          List {
            ForEach(metrics) { metric in
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(metric.type.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundColor(.gray)
                  HStack(spacing: 2) {
                    Text(String(format: "%.2f", metric.value))
                      .fontWeight(.semibold)
                    Text(metric.unit)
                      .font(.caption)
                      .foregroundColor(.gray)
                  }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                  Text(metric.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
                  Text(metric.source.capitalized)
                    .font(.caption2)
                    .foregroundColor(.blue)
                }
              }
              .padding(.vertical, 4)
            }
          }
        }
      }
      .navigationTitle("History")
    }
  }
}

#Preview {
  HistoryView()
    .modelContainer(for: StoredHealthMetric.self, inMemory: true)
}

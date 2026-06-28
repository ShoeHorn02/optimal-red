import Foundation
import SwiftData

@Model
final class StoredHealthMetric {
  @Attribute(.unique) var id: String
  var type: String
  var value: Double
  var unit: String
  var recordedAt: Date
  var source: String
  var syncedAt: Date?

  init(
    id: String = UUID().uuidString,
    type: String,
    value: Double,
    unit: String,
    recordedAt: Date = Date(),
    source: String = "ios",
    syncedAt: Date? = nil
  ) {
    self.id = id
    self.type = type
    self.value = value
    self.unit = unit
    self.recordedAt = recordedAt
    self.source = source
    self.syncedAt = syncedAt
  }
}

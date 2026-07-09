import Foundation
import SwiftData

@Model
final class PantryItem {
  var name: String
  var createdAt: Date

  init(name: String, createdAt: Date = .now) {
    self.name = name
    self.createdAt = createdAt
  }
}

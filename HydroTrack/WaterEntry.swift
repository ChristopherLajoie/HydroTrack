import Foundation
import SwiftData

@Model
final class WaterEntry {
    var timestamp: Date
    var amountML: Int
    
    init(timestamp: Date, amountML: Int) {
        self.timestamp = timestamp
        self.amountML = amountML
    }
}

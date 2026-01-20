import Foundation
import SwiftData

@Model
final class WaterEntry {
    var timestamp: Date
    var amountML: Int

    // New (optional) metadata so History can show “Container + fraction” instead of mL.
    var containerID: UUID?
    var fractionNumerator: Int?
    var fractionDenominator: Int?

    init(
        timestamp: Date = Date(),
        amountML: Int,
        containerID: UUID? = nil,
        fractionNumerator: Int? = nil,
        fractionDenominator: Int? = nil
    ) {
        self.timestamp = timestamp
        self.amountML = amountML
        self.containerID = containerID
        self.fractionNumerator = fractionNumerator
        self.fractionDenominator = fractionDenominator
    }
}

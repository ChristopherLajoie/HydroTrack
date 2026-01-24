import Foundation
import SwiftData

@Model
final class WaterEntry {
    var timestamp: Date
    var amountML: Int
    var isTrainingDay: Bool  // New field

    // Metadata so History can show "Container + fraction" instead of mL.
    var containerID: UUID?
    var fractionNumerator: Int?
    var fractionDenominator: Int?

    init(
        timestamp: Date = Date(),
        amountML: Int,
        isTrainingDay: Bool = false,  // New parameter
        containerID: UUID? = nil,
        fractionNumerator: Int? = nil,
        fractionDenominator: Int? = nil
    ) {
        self.timestamp = timestamp
        self.amountML = amountML
        self.isTrainingDay = isTrainingDay
        self.containerID = containerID
        self.fractionNumerator = fractionNumerator
        self.fractionDenominator = fractionDenominator
    }
}

//
//  Item.swift
//  HydroTrack
//
//  Created by Christopher Lajoie on 2026-01-14.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

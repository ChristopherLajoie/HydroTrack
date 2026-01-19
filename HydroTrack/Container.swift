//
//  Container.swift
//  HydroTrack
//
//  Created by Christopher Lajoie on 2026-01-19.
//


import Foundation

struct Container: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var volumeML: Int
    var emoji: String
    
    // Default containers
    static let defaults = [
        Container(name: "Water Bottle", volumeML: 500, emoji: "💧"),
        Container(name: "Glass", volumeML: 250, emoji: "🥤"),
        Container(name: "Large Glass", volumeML: 350, emoji: "🍶"),
        Container(name: "Coffee Mug", volumeML: 300, emoji: "☕️")
    ]
}

// Helper for AppStorage encoding/decoding
extension Array where Element == Container {
    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
    
    static func fromJSON(_ json: String) -> [Container] {
        guard let data = json.data(using: .utf8),
              let containers = try? JSONDecoder().decode([Container].self, from: data) else {
            return Container.defaults
        }
        return containers
    }
}

import Foundation
import UIKit

struct Container: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var volumeML: Int
    var emoji: String
    var imageName: String? // Optional: filename of saved image
    
    static var defaults: [Container] = [
        Container(name: "Small Cup", volumeML: 250, emoji: "☕️", imageName: nil),
        Container(name: "Glass", volumeML: 350, emoji: "🥤", imageName: nil),
        Container(name: "Bottle", volumeML: 500, emoji: "💧", imageName: nil),
        Container(name: "Large Bottle", volumeML: 750, emoji: "🍶", imageName: nil)
    ]
}

// MARK: - Image Storage Helper
extension Container {
    // Save image to disk and return filename
    static func saveImage(_ image: UIImage) -> String? {
        guard let data = image.pngData() else { return nil }  // Changed from jpegData to pngData
        
        let filename = "\(UUID().uuidString).png"  // Changed from .jpg to .png
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    // Load image from disk
    static func loadImage(filename: String) -> UIImage? {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    // Delete image from disk
    static func deleteImage(filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    private static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}


// MARK: - JSON Encoding
extension Array where Element == Container {
    func toJSON() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
    }
    
    static func fromJSON(_ jsonString: String) -> [Container] {
        guard let data = jsonString.data(using: .utf8) else {
            return Container.defaults
        }
        
        let decoder = JSONDecoder()
        return (try? decoder.decode([Container].self, from: data)) ?? Container.defaults
    }
}

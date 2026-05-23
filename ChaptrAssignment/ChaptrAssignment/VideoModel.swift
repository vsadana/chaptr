import Foundation

struct VideoItem: Codable, Identifiable {
    let id: Int
    let title: String
    let duration: Int
    let width: Int
    let height: Int
    let url: String
    let thumbnail: String
    // Optionally, add a computed property for a generated description
    var description: String {
        "Enjoy \(title.lowercased()). Duration: \(duration / 60)m \(duration % 60)s."
    }
}

struct VideoCatalog: Codable {
    let videos: [VideoItem]
}

class VideoDataLoader {
    static func loadCatalog() -> [VideoItem] {
        guard let url = Bundle.main.url(forResource: "for-you", withExtension: "json") else {
            print("for-you.json not found")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(VideoCatalog.self, from: data)
            return catalog.videos
        } catch {
            print("Failed to load or decode for-you.json: \(error)")
            return []
        }
    }
}

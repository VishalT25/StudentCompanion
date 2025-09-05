import Foundation

struct Secrets {
    static let apiKey: String = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else {
            fatalError("Secrets.plist not found. Please add it to your project.")
        }
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not read Secrets.plist")
        }
        guard let secrets = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            fatalError("Could not deserialize Secrets.plist")
        }
        guard let apiKey = secrets["API_KEY"] as? String else {
            fatalError("API_KEY not found in Secrets.plist")
        }
        return apiKey
    }()
}
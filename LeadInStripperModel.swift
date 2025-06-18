import CoreML
import NaturalLanguage

/// Singleton wrapper around the Core-ML token-classifier.
/// The model must be added to the Xcode project (drag ‘fluffClassifier.mlmodel’).
final class LeadInStripperModel {
    static let shared = LeadInStripperModel()
    private let model: NLModel
    
    private init() {
        guard let mlModelURL = Bundle.main.url(forResource: "fluffClassifier",
                                               withExtension: "mlmodelc"),
              let nlModel = try? NLModel(contentsOf: mlModelURL) else {
            fatalError("⚠️  fluffClassifier model not found.")
        }
        self.model = nlModel
    }
    
    /// Returns the input minus any tokens tagged FLUFF.
    func stripLeadIn(from text: String) -> String {
        let tokens = text.split { $0.isWhitespace || $0.isNewline }
        let filtered = tokens.filter { token in
            let label = model.predictedLabel(for: String(token)) ?? "CONTENT"
            return label != "FLUFF"
        }
        return filtered.joined(separator: " ")
    }
}

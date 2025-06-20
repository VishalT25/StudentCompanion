import Foundation
import CoreML

// MARK: - TF-IDF Vectoriser (unchanged except for public dimension)
final class TFIDFVectorizer {
    private let vocabulary: [String: Int]
    private let idf:        [Double]
    private let maxFeat:    Int
    var dimension: Int { maxFeat }

    init?(vocabularyFile: String, tfidfParamsFile: String) {
        guard
            let vURL = Bundle.main.url(forResource: vocabularyFile, withExtension: nil),
            let pURL = Bundle.main.url(forResource: tfidfParamsFile, withExtension: nil),
            let vData = try? Data(contentsOf: vURL),
            let pData = try? Data(contentsOf: pURL)
        else { return nil }

        struct Params: Codable { let vocabulary: [String:Int]; let idf_scores:[Double]; let max_features:Int }
        guard
            let vocab  = try? JSONDecoder().decode([String:Int].self, from: vData),
            let params = try? JSONDecoder().decode(Params.self,             from: pData)
        else { return nil }

        vocabulary = vocab
        idf        = params.idf_scores
        maxFeat    = params.max_features
    }

    func vectorize(text: String) -> [Double] {
        let tokens = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        var tf: [String:Int] = [:]
        tokens.forEach { tf[$0, default: 0] += 1 }

        var vec = Array(repeating: 0.0, count: maxFeat)
        for (w,c) in tf {
            if let idx = vocabulary[w] {
                vec[idx] = Double(c) / Double(tokens.count) * idf[idx]
            }
        }
        return vec
    }
}

// MARK: - IntentClassifier ----------------------------------------------------
final class IntentClassifier {

    fileprivate enum InputStyle {         // or just `enum InputStyle`
        case multiArray(name: String)
        case scalarFeatures(prefix: String, count: Int)
    }
    private let model      : MLModel
    private let vectorizer : TFIDFVectorizer
    private let inputStyle : InputStyle
    private let labelKey   : String
    private let probKey    : String?

    // --------------------------------------------------------------------
    init?() {

        // vectoriser
        guard let vec = TFIDFVectorizer(vocabularyFile: "vocabulary.json",
                                        tfidfParamsFile: "tfidf_params.json") else { return nil }
        self.vectorizer = vec

        // model
        let wrapped: MLModel
        do { wrapped = try StudentCompanionClassifier(configuration: .init()).model }
        catch { print("❌ Core ML load failed: \(error)"); return nil }
        self.model = wrapped
        let desc = wrapped.modelDescription

        // discover outputs
        var tmpLabel : String? = nil
        var tmpProb  : String? = nil
        for (n,d) in desc.outputDescriptionsByName {
            if d.type == .string     { tmpLabel = n }
            if d.type == .dictionary { tmpProb  = n }
        }
        guard let lbl = tmpLabel else {
            print("❌ No string output in model"); return nil }
        labelKey = lbl; probKey = tmpProb

        // discover input style
        if desc.inputDescriptionsByName.count == 1,
           let (n,d) = desc.inputDescriptionsByName.first,
           d.type == .multiArray {
            inputStyle = .multiArray(name: n)
        } else {
            // assume feature_0 … feature_(n-1)
            let count = desc.inputDescriptionsByName.count
            inputStyle = .scalarFeatures(prefix: "feature_", count: count)
        }

        print("✅ Core ML ready – style: \(inputStyle)  label: \(labelKey)")
    }

    // --------------------------------------------------------------------
    func predictIntentWithConfidence(from text: String)
        -> (intent:String, confidence:Double)?
    {
        let vec = vectorizer.vectorize(text: text)
        let provider: MLDictionaryFeatureProvider

        do {
            switch inputStyle {

            case .multiArray(let name):
                guard let arr = try? MLMultiArray(shape:[NSNumber(value:vec.count)],
                                                  dataType:.double) else { return nil }
                for (i,v) in vec.enumerated() { arr[i] = v as NSNumber }
                provider = try MLDictionaryFeatureProvider(dictionary: [name: arr])

            case .scalarFeatures(let prefix, let count):
                var dict = [String: MLFeatureValue](minimumCapacity: count)
                for i in 0..<count {
                    let key = "\(prefix)\(i)"
                    dict[key] = MLFeatureValue(double: vec[i])
                }
                provider = try MLDictionaryFeatureProvider(dictionary: dict)
            }

            let out = try model.prediction(from: provider)
            guard let label = out.featureValue(for: labelKey)?.stringValue else { return nil }

            var conf = 1.0
            if let pk = probKey,
               let probs = out.featureValue(for: pk)?.dictionaryValue as? [String:Double] {
                conf = probs[label] ?? 1.0
            }
            return (label, conf)

        } catch {
            print("⚠️  ML prediction error: \(error)")
            return nil
        }
    }

    func predictIntent(from text:String) -> String? {
        predictIntentWithConfidence(from: text)?.intent
    }
}

// nice debug print
extension IntentClassifier.InputStyle: CustomStringConvertible {
    var description: String {
        switch self {
        case .multiArray(let n):         return "multiArray(\(n))"
        case .scalarFeatures(_, let c):  return "scalar×\(c)"
        }
    }
}

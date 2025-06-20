import json
import coremltools as ct
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, accuracy_score
import joblib
import numpy as np
import sklearn
import traceback


def train_student_companion_model():
    """
    Train text classification model for student companion app
    """
    # Load training data
    try:
        with open('training_data.json', 'r') as f:
            train_data = json.load(f)

        with open('test_data.json', 'r') as f:
            test_data = json.load(f)
    except FileNotFoundError:
        print("Error: training_data.json or test_data.json not found. Please run multiwoz_processor.py first.")
        return

    # Prepare data
    X_train = [item['text'] for item in train_data]
    y_train = [item['label'] for item in train_data]

    X_test = [item['text'] for item in test_data]
    y_test = [item['label'] for item in test_data]

    if not y_train or not y_test:
        print("Error: Training or testing data has no labels. Please check multiwoz_processor.py output.")
        return

    # Print training data label distribution
    train_labels, train_counts = np.unique(y_train, return_counts=True)
    print("\nTraining data label distribution:")
    for label, count in zip(train_labels, train_counts):
        print(f"  {label}: {count}")

    # Create and train model
    vectorizer = TfidfVectorizer(
        max_features=1000,
        stop_words='english',
        lowercase=True,
        ngram_range=(1, 2)
    )

    # Use class_weight='balanced' to handle class imbalance
    classifier = RandomForestClassifier(
        n_estimators=100,
        random_state=42,
        max_depth=10,
        class_weight='balanced'
    )

    # Fit vectorizer and transform data
    X_train_vectorized = vectorizer.fit_transform(X_train)
    X_test_vectorized = vectorizer.transform(X_test)

    # Train classifier
    classifier.fit(X_train_vectorized, y_train)

    # Evaluate model
    y_pred = classifier.predict(X_test_vectorized)
    accuracy = accuracy_score(y_test, y_pred)
    print(f"\nModel Accuracy: {accuracy:.3f}")

    all_possible_labels = sorted(list(set(y_train) | set(y_test)))

    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, labels=all_possible_labels, zero_division=0))

    # Save vectorizer vocabulary for iOS implementation
    vocabulary = vectorizer.get_feature_names_out()
    vocab_dict = {word: idx for idx, word in enumerate(vocabulary)}

    with open('vocabulary.json', 'w') as f:
        json.dump(vocab_dict, f, indent=2)

    # Save TF-IDF parameters
    tfidf_params = {
        'vocabulary': vocab_dict,
        'idf_scores': vectorizer.idf_.tolist(),
        'max_features': vectorizer.max_features
    }

    with open('tfidf_params.json', 'w') as f:
        json.dump(tfidf_params, f, indent=2)

    # Convert to CoreML using the correct API
    print("\nAttempting CoreML conversion...")
    try:
        sklearn_version = tuple(map(int, sklearn.__version__.split('.')))

        # Check scikit-learn compatibility
        if sklearn_version >= (0, 17, 0) and sklearn_version <= (1, 1, 2):
            n_features = X_train_vectorized.shape[1]
            print(f"Creating CoreML model with {n_features} features...")

            # Generate feature names for each dimension
            feature_names = [f"feature_{i}" for i in range(n_features)]

            # CORRECTED: Use tuple for classifier outputs
            coreml_model = ct.converters.sklearn.convert(
                classifier,
                input_features=feature_names,
                output_feature_names=('intent_label', 'intent_probs')
            )

            # Add metadata
            coreml_model.short_description = "Student Companion Intent Classifier"
            coreml_model.author = "Student Companion App"
            coreml_model.license = "MIT"
            coreml_model.version = "1.2"

            # Save the model
            coreml_model.save('StudentCompanionClassifier.mlmodel')
            print("'StudentCompanionClassifier.mlmodel' saved successfully.")

        else:
            print(f"Scikit-learn version {sklearn.__version__} is not supported by coremltools for direct conversion.")
            print("To enable CoreML conversion, please downgrade scikit-learn to version 0.17.x to 1.1.2")
            print("Command: pip install scikit-learn==1.1.2")
            raise Exception("Incompatible scikit-learn version")

    except Exception as e:
        print(f"Error during CoreML conversion: {e}")
        traceback.print_exc()
        print("Saving as pickle file instead...")
        joblib.dump(classifier, 'student_classifier.pkl')
        print("Model saved as 'student_classifier.pkl'")

        # Save model info for debugging
        model_info = {
            'input_shape': X_train_vectorized.shape[1],
            'output_labels': sorted(list(set(y_train))),
            'sklearn_version': sklearn.__version__,
            'coremltools_version': ct.__version__ if hasattr(ct, '__version__') else 'unknown',
            'error_message': str(e)
        }

        with open('model_info.json', 'w') as f:
            json.dump(model_info, f, indent=2)

        print("Model information saved to 'model_info.json'")


if __name__ == "__main__":
    train_student_companion_model()

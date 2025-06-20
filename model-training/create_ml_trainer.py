import json
import pandas as pd


def create_createml_format():
    """
    Create JSON format compatible with Create ML
    """
    # Load your processed data
    with open('training_data.json', 'r') as f:
        train_data = json.load(f)

    with open('test_data.json', 'r') as f:
        test_data = json.load(f)

    # Convert to Create ML format
    train_df = pd.DataFrame(train_data)
    test_df = pd.DataFrame(test_data)

    # Save as JSON for Create ML
    train_df.to_json('createml_training.json', orient='records', lines=False, indent=2)
    test_df.to_json('createml_testing.json', orient='records', lines=False, indent=2)

    print("Created Create ML compatible JSON files")


if __name__ == "__main__":
    create_createml_format()

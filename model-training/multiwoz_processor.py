import json
import pandas as pd
from sklearn.model_selection import train_test_split
import re
from datasets import load_dataset
import traceback  # Import traceback module for detailed error reporting


def process_multiwoz_for_student_companion():
    """
    Process MultiWOZ dataset and map to student companion intents
    """

    print("Loading MultiWOZ dataset...")
    try:
        dataset = load_dataset("pfb30/multi_woz_v22")
        train_data = dataset['train']

        print(f"Successfully loaded MultiWOZ with {len(train_data)} dialogues.")

        # --- Start Comprehensive Debugging of Dataset Structure ---
        if len(train_data) > 0:
            print("\n--- Examining First Dialogue Structure (from HuggingFace datasets library) ---")
            first_dialogue = train_data[0]
            print(f"Dialogue ID: {first_dialogue.get('dialogue_id')}")
            print(f"Services: {first_dialogue.get('services')}")

            turns_data = first_dialogue.get('turns', {})  # Renamed to turns_data to avoid confusion
            print(f"Type of turns_data: {type(turns_data)}")

            # Use 'utterance' list length to determine number of turns if 'speaker' is also present
            num_turns_in_dialogue = len(turns_data.get('utterance', []))
            print(f"Turns count (based on utterance list): {num_turns_in_dialogue}.")

            print("\nFirst 5 turns details (if available):")
            for i in range(min(5, num_turns_in_dialogue)):  # Iterate by index
                # Access data using indexing into the lists within turns_data
                speaker_raw = turns_data['speaker'][i]
                utterance_text = turns_data['utterance'][i]
                dialogue_acts_for_turn = turns_data['dialogue_acts'][i]

                speaker_str = 'USER' if speaker_raw == 0 else ('SYSTEM' if speaker_raw == 1 else 'UNKNOWN')

                print(f"  Turn {i}:")
                print(f"    Speaker: '{speaker_str}' (raw: {speaker_raw}, type: {type(speaker_raw)})")
                print(
                    f"    Utterance: '{utterance_text}' (length: {len(utterance_text) if isinstance(utterance_text, str) else 'N/A'})")
                print(f"    Raw Dialogue Acts (for this turn): {dialogue_acts_for_turn}")
                print("-" * 20)
        # --- End Comprehensive Debugging ---

    except Exception as e:
        print(f"\nAn unexpected error occurred during MultiWOZ dataset loading or initial inspection: {e}")
        traceback.print_exc()  # This will print the full traceback!
        return process_with_local_data()  # Fallback to local data if loading fails

    # Map MultiWOZ dialog acts to student companion intents
    intent_mapping = {
        'book': 'schedule_task', 'booking': 'schedule_task',
        'inform': 'search_info', 'request': 'general_query',
        'recommend': 'search_info', 'select': 'search_info',
        'greet': 'general_query', 'bye': 'general_query', 'thank': 'general_query',
        'negate': 'general_query', 'confirm': 'general_query', 'dontcare': 'general_query',
        'repeat': 'general_query', 'reqmore': 'general_query', 'welcom': 'general_query',
        'deny': 'general_query', 'goodbye': 'general_query',

        'hotel-inform': 'search_info', 'restaurant-inform': 'search_info',
        'attraction-inform': 'search_info', 'train-inform': 'search_info',
        'hospital-inform': 'search_info', 'police-inform': 'search_info',
        'hotel-request': 'general_query', 'restaurant-request': 'general_query',
        'attraction-request': 'general_query', 'train-request': 'general_query',
        'hotel-book': 'schedule_task', 'restaurant-book': 'schedule_task',
        'train-book': 'schedule_task', 'taxi-book': 'schedule_task',
    }

    training_data = []
    processed_count = 0
    dialogue_limit = 500  # Process first 500 dialogues to get a good sample

    print("\nProcessing MultiWOZ dialogues for intent extraction...")

    for dialogue_idx, dialogue in enumerate(train_data):
        if dialogue_idx >= dialogue_limit:
            print(f"Stopping MultiWOZ processing after {dialogue_idx} dialogues (limit: {dialogue_limit}).")
            break

        if (dialogue_idx + 1) % 50 == 0:
            print(
                f"Processed {dialogue_idx + 1} dialogues, extracted {len(training_data)} samples so far from MultiWOZ.")

        # Access the 'turns' dictionary within the dialogue
        turns_data = dialogue.get('turns', {})

        # Get the number of turns for this dialogue based on the 'utterance' list
        num_turns_in_dialogue = len(turns_data.get('utterance', []))

        if num_turns_in_dialogue == 0:
            continue  # Skip dialogues with no turns or malformed 'turns' structure

        for turn_idx in range(num_turns_in_dialogue):
            try:
                # Access speaker, utterance, and dialogue_acts for the current turn by index
                speaker_raw = turns_data['speaker'][turn_idx]
                utterance_text = turns_data['utterance'][turn_idx]
                dialogue_acts_for_turn = turns_data['dialogue_acts'][turn_idx]

                # We are interested in USER turns for intent classification
                if speaker_raw == 0:  # 0 represents USER
                    utterance = utterance_text.strip()

                    if len(utterance) < 5:  # Skip very short utterances
                        continue

                    # dialogue_acts_for_turn is a LIST of dicts, as shown in paste-3.txt
                    predicted_intent = extract_intent_from_multiwoz_v22_dialog_acts(dialogue_acts_for_turn,
                                                                                    intent_mapping)

                    if predicted_intent:
                        training_data.append({
                            "text": utterance,
                            "label": predicted_intent
                        })
                        processed_count += 1

                        if processed_count <= 10:
                            print(f"  --> Extracted (MultiWOZ): '{utterance}' -> {predicted_intent}")

            except Exception as e:
                print(f"Error processing dialogue {dialogue_idx}, turn {turn_idx}: {e}")
                traceback.print_exc()
                continue

    print(f"\nExtracted {len(training_data)} samples from MultiWOZ successfully.")

    # Add student-specific training samples (rest of the file is unchanged)
    student_samples = [
        {"text": "Help me study for my math exam", "label": "study_help"},
        {"text": "I need to take notes during the lecture", "label": "note_taking"},
        {"text": "Remind me about my assignment due tomorrow", "label": "assignment_reminder"},
        {"text": "What's my current grade in chemistry", "label": "grade_tracking"},
        {"text": "Schedule my biology class for next week", "label": "schedule_class"},
        {"text": "I need help preparing for finals", "label": "exam_prep"},
        {"text": "What are the library hours today", "label": "library_hours"},
        {"text": "Tell me about my computer science course", "label": "course_info"},
        {"text": "Can you help me with this question", "label": "general_query"},

        {"text": "I have a test coming up and need study tips", "label": "study_help"},
        {"text": "Create a note about today's physics lecture", "label": "note_taking"},
        {"text": "Don't let me forget my essay is due Friday", "label": "assignment_reminder"},
        {"text": "How am I doing in organic chemistry", "label": "grade_tracking"},
        {"text": "Add calculus to my weekly schedule", "label": "schedule_class"},
        {"text": "I need to prepare for my midterm", "label": "exam_prep"},
        {"text": "When does the library close", "label": "library_hours"},
        {"text": "Show me details about my history course", "label": "course_info"},
        {"text": "I need help with this homework problem", "label": "general_query"},

        {"text": "yo croski help me study for calculus", "label": "study_help"},
        {"text": "yo croski I got a 95% on my chemistry test", "label": "grade_tracking"},
        {"text": "yo croski remind me to finish my homework", "label": "assignment_reminder"},
        {"text": "I have chemistry class every Monday at 9am", "label": "schedule_class"},

        {"text": "I need to book a study room", "label": "schedule_task"},
        {"text": "Can you find me information about the math department", "label": "search_info"},
        {"text": "I'm looking for a good place to study", "label": "search_info"},
        {"text": "Reserve a table at the library", "label": "schedule_task"},
        {"text": "I want to book a tutoring session", "label": "schedule_task"},
        {"text": "Find me information about office hours", "label": "search_info"},
        {"text": "I need details about the exam schedule", "label": "search_info"},
        {"text": "Book me a meeting with my advisor", "label": "schedule_task"},
    ]

    all_samples = training_data + student_samples

    print(f"\nTotal samples before split: {len(all_samples)}")

    if len(all_samples) < 2 * len(set(s['label'] for s in all_samples)):
        print("Not enough data for proper stratification, using simple split.")
        train_data_split, test_data_split = train_test_split(all_samples, test_size=0.2, random_state=42)
    else:
        try:
            train_data_split, test_data_split = train_test_split(
                all_samples,
                test_size=0.2,
                random_state=42,
                stratify=[s['label'] for s in all_samples]
            )
        except ValueError as e:
            print(f"Stratification failed ({e}), using simple split.")
            train_data_split, test_data_split = train_test_split(all_samples, test_size=0.2, random_state=42)

    with open('training_data.json', 'w') as f:
        json.dump(train_data_split, f, indent=2)

    with open('test_data.json', 'w') as f:
        json.dump(test_data_split, f, indent=2)

    print(f"Created training data with {len(train_data_split)} samples.")
    print(f"Created test data with {len(test_data_split)} samples.")

    label_counts = {}
    for sample in all_samples:
        label = sample['label']
        label_counts[label] = label_counts.get(label, 0) + 1

    print("\nLabel distribution (All Samples):")
    for label, count in sorted(label_counts.items()):
        print(f"  {label}: {count}")


def extract_intent_from_multiwoz_v22_dialog_acts(raw_dialog_acts_list, intent_mapping):
    """
    Extract intent from the raw MultiWOZ 2.2 dialogue_acts list for a single turn.

    Args:
        raw_dialog_acts_list (list): A list of dictionaries, where each dict has 'dialog_act' and 'span_info'.
                                     Example: [{'dialog_act': {'act_type': ['Hotel-Inform'], 'act_slots': []}, 'span_info': {...}}, ...]
        intent_mapping (dict): Your custom intent mapping.

    Returns:
        str: The predicted intent or 'general_query' as a fallback.
    """

    if not isinstance(raw_dialog_acts_list, list) or not raw_dialog_acts_list:
        return 'general_query'

    # Iterate through each dialog act item in the list for this turn
    for dialog_act_item in raw_dialog_acts_list:
        if isinstance(dialog_act_item, dict) and 'dialog_act' in dialog_act_item:
            dialog_act_detail = dialog_act_item['dialog_act']  # This is now the dict with 'act_type' and 'act_slots'

            if isinstance(dialog_act_detail, dict) and 'act_type' in dialog_act_detail:
                act_types = dialog_act_detail.get('act_type', [])

                if isinstance(act_types, list):
                    for act_type_str in act_types:  # Iterate through the list of act_types
                        if isinstance(act_type_str, str) and act_type_str:
                            act_lower = act_type_str.lower()

                            # Prioritize more specific mappings first
                            if 'hotel-book' in act_lower or 'restaurant-book' in act_lower or 'train-book' in act_lower or 'taxi-book' in act_lower:
                                return 'schedule_task'
                            if 'hotel-inform' in act_lower or 'restaurant-inform' in act_lower or 'attraction-inform' in act_lower or 'train-inform' in act_lower or 'hospital-inform' in act_lower or 'police-inform' in act_lower:
                                return 'search_info'
                            if 'hotel-request' in act_lower or 'restaurant-request' in act_lower or 'attraction-request' in act_lower or 'train-request' in act_lower:
                                return 'general_query'

                            # Then general mappings
                            for keyword, intent in intent_mapping.items():
                                if keyword in act_lower:
                                    return intent

    # If no specific mapping found after checking all acts, use general query
    return 'general_query'


def process_with_local_data():
    """Fallback method if HuggingFace loading fails or MultiWOZ extraction yields 0 samples."""
    print("Using local sample data for training data generation (MultiWOZ extraction failed or yielded 0 samples).")

    multiwoz_samples = [
        {"text": "I need to book a table for dinner", "label": "schedule_task"},
        {"text": "Can you help me find information about trains", "label": "search_info"},
        {"text": "I'm looking for a good restaurant nearby", "label": "search_info"},
        {"text": "Book me a hotel room for tonight", "label": "schedule_task"},
        {"text": "What time does the restaurant open", "label": "search_info"},
        {"text": "I need to reserve a taxi", "label": "schedule_task"},
        {"text": "Find me attractions in the city center", "label": "search_info"},
        {"text": "Book a train ticket to London", "label": "schedule_task"},
        {"text": "Where is the nearest hospital", "label": "search_info"},
        {"text": "I want to book a table for two", "label": "schedule_task"},
        {"text": "Can you recommend a good hotel", "label": "search_info"},
        {"text": "I need information about local attractions", "label": "search_info"},
        {"text": "Book me a taxi to the airport", "label": "schedule_task"},
        {"text": "What restaurants do you recommend", "label": "search_info"},
        {"text": "I want to make a reservation", "label": "schedule_task"},
    ]

    student_samples = [
        {"text": "Help me study for my math exam", "label": "study_help"},
        {"text": "I need to take notes during the lecture", "label": "note_taking"},
        {"text": "Remind me about my assignment due tomorrow", "label": "assignment_reminder"},
        {"text": "What's my current grade in chemistry", "label": "grade_tracking"},
        {"text": "Schedule my biology class for next week", "label": "schedule_class"},
        {"text": "I need help preparing for finals", "label": "exam_prep"},
        {"text": "What are the library hours today", "label": "library_hours"},
        {"text": "Tell me about my computer science course", "label": "course_info"},
        {"text": "Can you help me with this question", "label": "general_query"},
        {"text": "yo croski help me with calculus", "label": "study_help"},
        {"text": "I got a B+ on my physics test", "label": "grade_tracking"},
    ]

    all_samples = multiwoz_samples + student_samples

    train_data, test_data = train_test_split(all_samples, test_size=0.2, random_state=42)

    with open('training_data.json', 'w') as f:
        json.dump(train_data, f, indent=2)

    with open('test_data.json', 'w') as f:
        json.dump(test_data, f, indent=2)

    print(f"Created training data with {len(train_data)} samples.")
    print(f"Created test data with {len(test_data)} samples.")


if __name__ == "__main__":
    process_multiwoz_for_student_companion()

import json
import re

# Load your fixed entities file
with open("entities.json", "r") as f:
    data = json.load(f)

# Define regex for checking numeric grades
score_value_re = re.compile(r"\b\d{1,3}(?:\.\d+)?(?=\s*(%|percent|/))", re.IGNORECASE)
score_unit_re = re.compile(r"\b(%|percent|/100)\b", re.IGNORECASE)

def adjust_letter_grades(entry):
    tokens = entry["tokens"]
    tags = entry["tags"]
    text = " ".join(tokens)

    # Check for numeric grade presence
    has_numeric = bool(score_value_re.search(text) or score_unit_re.search(text))

    if has_numeric:
        # Remove B-LETTER_GRADE and I-LETTER_GRADE tags
        tags = [
            "O" if tag.startswith("B-LETTER_GRADE") or tag.startswith("I-LETTER_GRADE") else tag
            for tag in tags
        ]
        entry["tags"] = tags

    return entry

# Apply fix to all entries
adjusted = [adjust_letter_grades(entry) for entry in data]

# Save updated file
with open("entities_adjusted.json", "w") as f:
    json.dump(adjusted, f, indent=2)

print("✅ Fixed letter grade bias. Output saved to: entities_adjusted.json")

import json
import re

# Load the training data
with open("training_data.json", "r") as f:
    training_data = json.load(f)

# Entity regex patterns for grade_tracking
grade_keywords = {
    "SCORE_VALUE": r"\b\d{1,3}(?:\.\d+)?(?=\s*(?:%|percent|/))",
    "SCORE_UNIT": r"\b(?:%|percent|/100)\b",
    "MAX_SCORE": r"(?<=/)\d+",
    "LETTER_GRADE": r"\b[A-D][+-]?\b|F\b",
    "WEIGHT_PERCENT": r"\b\d{1,3}(?:\.\d+)?\s*(?:%|percent)\b",
    "ASSIGNMENT": r"\b(?:exam|quiz|test|assignment|midterm|final|project|presentation|report|paper|portfolio|lab)\b",
    "COURSE_NAME": r"\b(?:math|chemistry|biology|physics|history|english|geography|economics|psychology|statistics|art|music|philosophy|sociology|engineering|marketing|finance|law|anthropology|astronomy|computer science|calc|calculus|logic|ethics|business|drama|design|neuroscience|journalism|robotics|nutrition|algebra|geometry)\b",
}


# Basic tokenizer
def tokenize(text):
    return re.findall(r'\b\w+\b|[^\w\s]', text)


# BIO tagger
def tag_tokens(tokens, text):
    tags = ["O"] * len(tokens)
    token_spans = [(m.start(), m.end()) for m in re.finditer(r'\b\w+\b|[^\w\s]', text)]

    for label, pattern in grade_keywords.items():
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            match_start, match_end = match.start(), match.end()
            for i, (start, end) in enumerate(token_spans):
                if start >= match_start and end <= match_end:
                    tags[i] = f"B-{label}" if tags[i] == "O" else f"I-{label}"
    return tags


# Process all grade_tracking entries
output_data = []
for item in training_data:
    if item.get("label") != "grade_tracking":
        continue
    tokens = tokenize(item["text"])
    tags = tag_tokens(tokens, item["text"])
    output_data.append({
        "text": item["text"],
        "tokens": tokens,
        "tags": tags
    })

# Save as JSON
with open("grades_tagged.json", "w") as out_file:
    json.dump(output_data, out_file, indent=2)

print("✅ Done! Output saved to 'event_reminder_tagged.json'")


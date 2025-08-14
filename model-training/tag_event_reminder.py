import json
import re

with open("training_data.json", "r") as f:
    training_data = json.load(f)

reminder_keywords = {
    "EVENT": r"\b(?:remind me to|go to|hit|attend|join|schedule|do|complete|submit|finish|start|study for|review for|call|text|email|check on|work on|meet with|visit|pay for|return|buy|pick up|drop off|message|follow up with)(?:\s+(?:the\s+)?(?:\w+)){1,5}",
    "DATE_ABS": r"\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)(?: \d{1,2})(?:,? \d{4})?|\b\d{4}-\d{2}-\d{2}\b",
    "DATE_REL": r"\b(?:tomorrow|tmrw|tmr|today|tdy|todaym|yesterday|yday|tonight|this\s+\w+|next\s+\w+|in\s+\d+\s+\w+|in\s+\d+(min|hr|h|day)s?)\b",
    "TIME": r"\b(?:\d{1,2}(:\d{2})?\s*(am|pm)?|noon|midnight|now)\b",
    "REL_DURATION": r"\bin\s+\d+\s*(min(?:ute)?s?|h(?:ours?)?|hrs?|days?)\b",
    "CATEGORY": r"\b(?:academics?|fitness|health|finance|errands|work|school|leisure|personal|selfcare|routine|chores)\b",
    "REM_OFFSET": r"\b\d+\s*(min(?:ute)?s?|h(?:ours?)?|hrs?|days?)\s*(before|ahead|early)\b"
}

def tokenize(text):
    return re.findall(r'\b\w+\b|[^\w\s]', text)

def tag_tokens(tokens, text):
    tags = ["O"] * len(tokens)
    token_spans = [(m.start(), m.end()) for m in re.finditer(r'\b\w+\b|[^\w\s]', text)]
    for label, pattern in reminder_keywords.items():
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            m_start, m_end = match.start(), match.end()
            for i, (start, end) in enumerate(token_spans):
                if start >= m_start and end <= m_end:
                    tags[i] = f"B-{label}" if tags[i] == "O" else f"I-{label}"
    return tags

output_data = []
for item in training_data:
    if item.get("label") != "event_reminder":
        continue
    tokens = tokenize(item["text"])
    tags = tag_tokens(tokens, item["text"])
    output_data.append({
        "tokens": tokens,
        "labels": tags
    })

with open("event_reminder_tagged.json", "w") as f:
    json.dump(output_data, f, indent=2)

print("✅ Saved as event_reminder_tagged.json")

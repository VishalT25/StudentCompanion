import json
import re

with open("training_data.json", "r") as f:
    training_data = json.load(f)

scheduled_keywords = {
    "EVENT": r"\b(?:class|lecture|meeting|gym|workout|run|walk|training|shift|lab|session|practice|presentation|seminar|call|checkup|submission|essay|study session|group work|team sync|zoom call|office hours)\b",
    "TIME_START": r"\b(?:starts?\s+at\s+)?(?:\d{1,2}(:\d{2})?\s*(am|pm)?|noon|midnight)\b",
    "TIME_END": r"\b(?:ends?\s+at\s+)?(?:\d{1,2}(:\d{2})?\s*(am|pm)?|noon|midnight)\b",
    "DAY_OF_WEEK": r"\b(?:mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b",
    "REM_OFFSET": r"\b\d+\s*(min(?:ute)?s?|h(?:ours?)?|hrs?|days?)\s*(before|ahead|early)\b",
    "CATEGORY": r"\b(?:academics?|fitness|health|finance|errands|work|school|leisure|selfcare|routine)\b"
}

def tokenize(text):
    return re.findall(r'\b\w+\b|[^\w\s]', text)

def tag_tokens(tokens, text):
    tags = ["O"] * len(tokens)
    token_spans = [(m.start(), m.end()) for m in re.finditer(r'\b\w+\b|[^\w\s]', text)]
    for label, pattern in scheduled_keywords.items():
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            m_start, m_end = match.start(), match.end()
            for i, (start, end) in enumerate(token_spans):
                if start >= m_start and end <= m_end:
                    tags[i] = f"B-{label}" if tags[i] == "O" else f"I-{label}"
    return tags

output_data = []
for item in training_data:
    if item.get("label") != "scheduled_event":
        continue
    tokens = tokenize(item["text"])
    tags = tag_tokens(tokens, item["text"])
    output_data.append({
        "tokens": tokens,
        "labels": tags
    })

with open("scheduled_event_tagged.json", "w") as f:
    json.dump(output_data, f, indent=2)

print("✅ Saved as scheduled_event_tagged.json")

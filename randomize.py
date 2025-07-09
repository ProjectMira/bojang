import json
import random

# Path to your JSON file
file_path = "assets/quiz_data/level-2/weather-and-nature.json"

with open(file_path, "r", encoding="utf-8") as f:
    data = json.load(f)

for exercise in data.get("exercises", []):
    if "options" in exercise and "correctAnswerIndex" in exercise:
        options = exercise["options"]
        correct_idx = exercise["correctAnswerIndex"]
        correct_option = options[correct_idx]
        # Remove the correct answer
        options.pop(correct_idx)
        # Choose a new random index
        new_idx = random.randint(0, len(options))
        # Insert the correct answer at the new index
        options.insert(new_idx, correct_option)
        # Update the correctAnswerIndex
        exercise["correctAnswerIndex"] = new_idx

# Save back to the same file (or change to a new file if you want to keep the original)
with open(file_path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Randomization complete.")
#!/usr/bin/env python3
import json
import time
import os
import openai

# Set your OpenAI API key from environment variable
# export OPENAI_API_KEY="your-api-key"

def load_translations(filename="missing_translations.json"):
    """Load the translated labels from the JSON file."""
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data
    except Exception as e:
        print(f"Error loading file: {e}")
        return None

def clean_term_for_translation(term):
    """Clean a term for translation by extracting the main concept."""
    # For terms with scientific names or multiple descriptions, focus on the main concept
    if ',' in term:
        # Take only the first part before the comma
        main_term = term.split(',')[0].strip()
        return main_term
    return term

def translate_term(term):
    """Translate a single term using OpenAI API."""
    if not openai.api_key:
        try:
            openai.api_key = os.environ["OPENAI_API_KEY"]
        except KeyError:
            print("Error: OpenAI API key not found. Please set the OPENAI_API_KEY environment variable.")
            return None
    
    cleaned_term = clean_term_for_translation(term)
    prompt = f"Translate this English term to Chinese with pinyin: '{cleaned_term}'. Format as 'Chinese (pinyin)'."
    
    try:
        response = openai.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a professional translator. Provide only the Chinese translation and pinyin, nothing else."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3
        )
        
        # Parse the response
        translation_text = response.choices[0].message.content.strip()
        
        # Check if the format is "Chinese (pinyin)"
        if '(' in translation_text and ')' in translation_text:
            chinese = translation_text.split('(')[0].strip()
            pinyin = translation_text.split('(')[1].split(')')[0].strip()
            return (chinese, pinyin)
        else:
            # Try to extract Chinese and pinyin from unformatted response
            parts = translation_text.split()
            if len(parts) >= 2:
                chinese = parts[0]
                pinyin_parts = parts[1:]
                pinyin = ' '.join(pinyin_parts)
                return (chinese, pinyin)
        
        return None
        
    except Exception as e:
        print(f"Error translating '{term}': {e}")
        return None

def fix_missing_translations(data):
    """Find and fix missing translations in the data."""
    missing_count = 0
    fixed_count = 0
    
    # First, count missing translations
    for entry in data["objects"]:
        if not entry["chinese"] or not entry["pinyin"]:
            missing_count += 1
    
    print(f"Found {missing_count} entries with missing translations")
    
    # Fix missing translations
    for i, entry in enumerate(data["objects"]):
        if not entry["chinese"] or not entry["pinyin"]:
            print(f"Translating {i+1}/{missing_count}: {entry['english']}")
            
            result = translate_term(entry["english"])
            if result:
                chinese, pinyin = result
                entry["chinese"] = chinese
                entry["pinyin"] = pinyin
                fixed_count += 1
                print(f"  → {chinese} ({pinyin})")
            else:
                print(f"  Failed to translate: {entry['english']}")
            
            # Avoid rate limiting
            time.sleep(1)
    
    print(f"Fixed {fixed_count} out of {missing_count} missing translations")
    
    # Check if there are still missing translations
    still_missing = 0
    for entry in data["objects"]:
        if not entry["chinese"] or not entry["pinyin"]:
            still_missing += 1
    
    if still_missing > 0:
        print(f"Warning: {still_missing} entries still have missing translations")
    else:
        print("All translations have been fixed!")
    
    return data

def save_translations(data, filename="translated_labels_fixed.json"):
    """Save the fixed translations to a JSON file."""
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"Saved fixed translations to {filename}")

def main():
    print("Loading translations...")
    data = load_translations()
    if not data:
        return
    
    print("Fixing missing translations...")
    fixed_data = fix_missing_translations(data)
    
    print("Saving fixed translations...")
    save_translations(fixed_data)
    
    print("Done!")

if __name__ == "__main__":
    main() 
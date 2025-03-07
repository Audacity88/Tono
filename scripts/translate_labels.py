#!/usr/bin/env python3
import json
import requests
import time
import os
from urllib.parse import quote
import openai

# Set your OpenAI API key
# You can set this as an environment variable: export OPENAI_API_KEY="your-api-key"
# or uncomment and set it directly here:
# openai.api_key = "YOUR_OPENAI_API_KEY"

# Note: You'll need to get your own API key for a translation service
# This example uses DeepL API, but you can substitute any translation service
DEEPL_API_KEY = "YOUR_API_KEY_HERE"  # Replace with your actual API key

def load_labels(filename="imagenet_labels_for_translation.json"):
    """Load the labels from the JSON file."""
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data
    except Exception as e:
        print(f"Error loading file: {e}")
        return None

def translate_text_deepl(text, target_lang="ZH"):
    """Translate text using DeepL API."""
    url = f"https://api-free.deepl.com/v2/translate"
    params = {
        "auth_key": DEEPL_API_KEY,
        "text": text,
        "target_lang": target_lang
    }
    
    try:
        response = requests.post(url, data=params)
        if response.status_code == 200:
            result = response.json()
            return result["translations"][0]["text"]
        else:
            print(f"Translation error: {response.status_code}")
            return None
    except Exception as e:
        print(f"Translation request error: {e}")
        return None

def translate_text_google(text, target_lang="zh-CN"):
    """Translate text using Google Translate (no API key required, but limited usage)."""
    base_url = "https://translate.googleapis.com/translate_a/single"
    params = {
        "client": "gtx",
        "sl": "en",
        "tl": target_lang,
        "dt": "t",
        "q": text
    }
    
    url = f"{base_url}?client={params['client']}&sl={params['sl']}&tl={params['tl']}&dt={params['dt']}&q={quote(params['q'])}"
    
    try:
        response = requests.get(url)
        if response.status_code == 200:
            result = response.json()
            return result[0][0][0]
        else:
            print(f"Translation error: {response.status_code}")
            return None
    except Exception as e:
        print(f"Translation request error: {e}")
        return None

def clean_term_for_translation(term):
    """Clean a term for translation by extracting the main concept."""
    # For terms with scientific names or multiple descriptions, focus on the main concept
    if ',' in term:
        # Take only the first part before the comma
        main_term = term.split(',')[0].strip()
        return main_term
    return term

def translate_text_openai(text_list, batch_size=15):
    """
    Translate a list of English phrases to Chinese with pinyin using OpenAI API.
    Returns a dictionary mapping English phrases to (Chinese, pinyin) tuples.
    """
    if not openai.api_key:
        try:
            openai.api_key = os.environ["OPENAI_API_KEY"]
        except KeyError:
            print("Error: OpenAI API key not found. Please set the OPENAI_API_KEY environment variable.")
            return {}
    
    results = {}
    
    # Process in batches to avoid hitting token limits
    for i in range(0, len(text_list), batch_size):
        batch = text_list[i:i+batch_size]
        print(f"Translating batch {i//batch_size + 1}/{(len(text_list) + batch_size - 1)//batch_size}")
        
        # Create a prompt for the batch
        prompt = """Translate the following English terms to Chinese and provide the pinyin with tone marks. 
These are ImageNet class labels, so focus on translating the main concept accurately.
For terms with scientific names or multiple descriptions, focus on the main concept (before the first comma).

Format each response as 'English: Chinese (pinyin)'

"""
        for term in batch:
            prompt += f"- {term}\n"
        
        try:
            response = openai.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a professional translator specializing in English to Chinese translation for computer vision and image recognition. Provide accurate translations with correct pinyin including tone marks. For terms with scientific names or multiple descriptions, focus on translating the main concept accurately."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3
            )
            
            # Parse the response
            translation_text = response.choices[0].message.content
            
            # Process each line of the response
            for line in translation_text.strip().split('\n'):
                if ':' in line:
                    # Extract English, Chinese, and pinyin
                    parts = line.split(':', 1)
                    english = parts[0].strip().strip('-').strip()
                    
                    # Extract Chinese and pinyin from the second part
                    chinese_pinyin = parts[1].strip()
                    
                    # Check if the format is "Chinese (pinyin)"
                    if '(' in chinese_pinyin and ')' in chinese_pinyin:
                        chinese = chinese_pinyin.split('(')[0].strip()
                        pinyin = chinese_pinyin.split('(')[1].split(')')[0].strip()
                        
                        # Find the matching original English phrase from our batch
                        for original_phrase in batch:
                            # Try to match the cleaned version of the original phrase
                            cleaned_original = clean_term_for_translation(original_phrase)
                            if cleaned_original.lower() == english.lower() or original_phrase.lower() == english.lower():
                                results[original_phrase] = (chinese, pinyin)
                                break
                            # Fallback for partial matches
                            elif cleaned_original.lower() in english.lower() or english.lower() in cleaned_original.lower():
                                results[original_phrase] = (chinese, pinyin)
                                break
            
            # Avoid rate limiting
            time.sleep(1)
            
        except Exception as e:
            print(f"OpenAI API error: {e}")
            time.sleep(5)  # Wait longer on error
    
    return results

def translate_missing_terms(missing_terms):
    """Translate terms that were missed in the first pass."""
    print(f"Attempting to translate {len(missing_terms)} missing terms...")
    
    # For each missing term, try a more direct approach with a simpler prompt
    results = {}
    
    for term in missing_terms:
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
                results[term] = (chinese, pinyin)
                print(f"Successfully translated: {term} → {chinese} ({pinyin})")
            else:
                # Try to extract Chinese and pinyin from unformatted response
                parts = translation_text.split()
                if len(parts) >= 2:
                    chinese = parts[0]
                    pinyin_parts = parts[1:]
                    pinyin = ' '.join(pinyin_parts)
                    results[term] = (chinese, pinyin)
                    print(f"Extracted translation: {term} → {chinese} ({pinyin})")
            
            # Avoid rate limiting
            time.sleep(1)
            
        except Exception as e:
            print(f"Error translating '{term}': {e}")
            time.sleep(2)
    
    return results

def get_pinyin(chinese_text):
    """Get pinyin for Chinese text using an API."""
    # This is a placeholder - you would need to implement or use a service for this
    # For now, we'll leave it blank
    return ""

def translate_labels(data, use_openai=True, use_google=False):
    """Translate all labels in the data."""
    if not data or "objects" not in data:
        print("Invalid data format")
        return None
    
    total = len(data["objects"])
    print(f"Translating {total} labels...")
    
    if use_openai:
        # Collect all English phrases that need translation
        to_translate = []
        for entry in data["objects"]:
            if not entry["chinese"] or not entry["pinyin"]:
                to_translate.append(entry["english"])
        
        print(f"Found {len(to_translate)} labels to translate")
        
        # Translate in bulk using OpenAI
        translations = translate_text_openai(to_translate)
        
        # Update the data with translations
        translated_count = 0
        missing_terms = []
        
        for entry in data["objects"]:
            if entry["english"] in translations:
                chinese, pinyin = translations[entry["english"]]
                entry["chinese"] = chinese
                entry["pinyin"] = pinyin
                translated_count += 1
            elif not entry["chinese"] or not entry["pinyin"]:
                # Keep track of terms that weren't translated
                missing_terms.append(entry["english"])
        
        print(f"Successfully translated {translated_count} labels")
        
        # Check if there are any missing translations
        if missing_terms:
            print(f"Found {len(missing_terms)} terms without translations. Attempting to translate them individually...")
            missing_translations = translate_missing_terms(missing_terms)
            
            # Update the data with the missing translations
            for entry in data["objects"]:
                if entry["english"] in missing_translations:
                    chinese, pinyin = missing_translations[entry["english"]]
                    entry["chinese"] = chinese
                    entry["pinyin"] = pinyin
                    translated_count += 1
            
            print(f"After second pass: Successfully translated {translated_count} labels")
        
        # Final verification
        still_missing = 0
        for entry in data["objects"]:
            if not entry["chinese"] or not entry["pinyin"]:
                still_missing += 1
                print(f"Still missing translation for: {entry['english']}")
        
        if still_missing > 0:
            print(f"Warning: {still_missing} labels still don't have translations")
        else:
            print("All labels have been successfully translated!")
        
        return data
    
    # Original implementation for individual translations
    for i, entry in enumerate(data["objects"]):
        if i % 10 == 0:
            print(f"Progress: {i}/{total}")
        
        english = entry["english"]
        
        # Skip if already translated
        if entry["chinese"] and entry["pinyin"]:
            continue
        
        # For terms with scientific names, focus on the main concept
        translation_term = clean_term_for_translation(english)
        
        # Translate to Chinese
        if use_google:
            chinese = translate_text_google(translation_term)
        else:
            chinese = translate_text_deepl(translation_term)
        
        if chinese:
            entry["chinese"] = chinese
            # Get pinyin (in a real implementation, you would use a proper service)
            # entry["pinyin"] = get_pinyin(chinese)
        
        # Avoid rate limiting
        time.sleep(1)
    
    return data

def save_translated_labels(data, filename="translated_labels.json"):
    """Save the translated labels to a JSON file."""
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"Saved translated labels to {filename}")

def main():
    # Load the labels
    data = load_labels()
    if not data:
        return
    
    # Choose translation method
    print("Select translation method:")
    print("1. OpenAI API (best quality, includes pinyin)")
    print("2. Google Translate API (no key required, limited usage)")
    print("3. DeepL API (requires API key)")
    
    choice = input("Enter your choice (1-3): ").strip()
    
    # Translate the labels
    if choice == "1":
        translated_data = translate_labels(data, use_openai=True, use_google=False)
    elif choice == "2":
        translated_data = translate_labels(data, use_openai=False, use_google=True)
    else:
        translated_data = translate_labels(data, use_openai=False, use_google=False)
    
    if not translated_data:
        return
    
    # Save the translated labels
    save_translated_labels(translated_data)
    
    print("Translation complete! Review the translations before adding to your app.")

if __name__ == "__main__":
    main() 
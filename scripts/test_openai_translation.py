#!/usr/bin/env python3
import os
import json
import time
import openai

# Sample words to translate
SAMPLE_WORDS = [
    "apple",
    "computer",
    "keyboard",
    "mountain",
    "ocean",
    "camera",
    "bicycle",
    "umbrella",
    "coffee",
    "book"
]

def translate_text_openai(text_list, batch_size=10):
    """
    Translate a list of English words to Chinese with pinyin using OpenAI API.
    Returns a dictionary mapping English words to (Chinese, pinyin) tuples.
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
        prompt = "Translate the following English words to Chinese and provide the pinyin. Format each response as 'English: Chinese (pinyin)'\n\n"
        for word in batch:
            prompt += f"- {word}\n"
        
        try:
            response = openai.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": "You are a professional translator specializing in English to Chinese translation. Provide accurate translations with correct pinyin including tone marks."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.3
            )
            
            # Parse the response
            translation_text = response.choices[0].message.content
            print("\nRaw response from OpenAI:")
            print(translation_text)
            print("\nParsed translations:")
            
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
                        
                        # Find the matching original English word from our batch
                        for original_word in batch:
                            if original_word.lower() in english.lower() or english.lower() in original_word.lower():
                                results[original_word] = (chinese, pinyin)
                                print(f"{original_word}: {chinese} ({pinyin})")
                                break
            
        except Exception as e:
            print(f"OpenAI API error: {e}")
    
    return results

def main():
    print("Testing OpenAI translation with sample words...")
    
    # Check if API key is set
    if not os.environ.get("OPENAI_API_KEY"):
        print("Warning: OPENAI_API_KEY environment variable not set.")
        print("Please set it with: export OPENAI_API_KEY='your-api-key'")
        api_key = input("Or enter your OpenAI API key now: ").strip()
        if api_key:
            openai.api_key = api_key
        else:
            print("No API key provided. Exiting.")
            return
    
    # Translate sample words
    translations = translate_text_openai(SAMPLE_WORDS)
    
    # Save results to a file
    if translations:
        results = {
            "objects": [
                {
                    "english": word,
                    "chinese": chinese,
                    "pinyin": pinyin,
                    "category": "test_sample"
                }
                for word, (chinese, pinyin) in translations.items()
            ]
        }
        
        with open("sample_translations.json", "w", encoding="utf-8") as f:
            json.dump(results, f, ensure_ascii=False, indent=2)
        
        print(f"\nSaved {len(translations)} translations to sample_translations.json")
    else:
        print("No translations were generated.")

if __name__ == "__main__":
    main() 
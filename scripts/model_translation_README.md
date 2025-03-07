# Model Translation Scripts

This directory contains scripts to extract class labels from the Inceptionv3 model, translate them to Chinese, and merge them with your existing translations.

## Overview

The Inceptionv3 model can recognize 1,000 different object classes. These scripts help you:

1. Extract all class labels from the model
2. Translate them to Chinese (with pinyin)
3. Merge them with your existing translations

## Scripts

### 1. `extract_imagenet_labels.py`

This script downloads the ImageNet class labels that Inceptionv3 was trained on and formats them for translation.

**Usage:**
```bash
pip install requests
python extract_imagenet_labels.py
```

**Output:** `imagenet_labels_for_translation.json`

### 2. `translate_labels.py`

This script translates the extracted labels to Chinese. It can use one of three methods:

- **OpenAI API** (recommended): Provides high-quality translations with pinyin
  - Requires an OpenAI API key (set as `OPENAI_API_KEY` environment variable)
  - Processes labels in batches for efficiency
  - Automatically generates pinyin with tone marks

- **Google Translate API**: No key required, but limited usage
  - Free to use but has usage limits
  - Does not generate pinyin

- **DeepL API**: Requires an API key
  - High-quality translations
  - Does not generate pinyin

**Usage:**
```bash
# For OpenAI method
pip install openai requests
export OPENAI_API_KEY="your-api-key"
python translate_labels.py
```

**Output:** `translated_labels.json`

### 3. `merge_translations.py`

This script merges the translated labels with your existing translations.json file, avoiding duplicates.

**Usage:**
```bash
python merge_translations.py
```

**Output:** `Tono/Resources/translations_merged.json`

## Complete Workflow

1. Run `extract_imagenet_labels.py` to get the class labels
2. Run `translate_labels.py` to translate them to Chinese (select OpenAI method for best results)
3. Manually review and edit the translations if needed
4. Run `merge_translations.py` to merge with your existing translations
5. Review the merged file and replace your original translations.json if satisfied

## Notes

- The OpenAI method provides the best quality translations and automatically includes pinyin with tone marks
- The Google Translate method doesn't require an API key but has usage limits
- For a production app, consider using a paid translation service for better quality
- Always review machine translations before using them in your app 
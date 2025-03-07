# ImageNet Translation Scripts

This directory contains scripts for extracting and translating ImageNet class labels for use in the Tono AR application.

## Updates

The scripts have been updated to:
1. Fetch accurate ImageNet categories from the Waikato University reference site
2. Use the full term sets (e.g., "mouse, computer mouse") for better context
3. Translate terms as complete phrases for better accuracy
4. Provide meaningful categories based on the main concept
5. Ensure all labels get translated with a two-pass approach

## Scripts

### 1. `extract_imagenet_labels.py`

This script downloads the ImageNet class labels and prepares them for translation. It fetches the full term sets from the Waikato University reference site to provide complete descriptions for each label.

**Usage:**
```
python extract_imagenet_labels.py
```

**Output:** `imagenet_labels_for_translation.json`

### 2. `translate_labels.py`

This script translates the extracted labels to Chinese using one of three methods:
- OpenAI API (recommended for best quality and pinyin)
- Google Translate API (no API key required, but limited usage)
- DeepL API (requires API key)

The script has been improved to handle full term sets and focus on translating the main concept accurately. It now includes a second pass to catch any missing translations.

**Usage:**
```
python translate_labels.py
```

**Output:** `translated_labels.json`

### 3. `fix_missing_translations.py`

This script checks an existing `translated_labels.json` file for any missing translations and attempts to fix them using the OpenAI API.

**Usage:**
```
python fix_missing_translations.py
```

**Output:** `translated_labels_fixed.json`

## Installation

Run the installation script to install the required dependencies:

```
./install_dependencies.sh
```

## Complete Workflow

1. Run `./install_dependencies.sh` to install required packages
2. Run `python extract_imagenet_labels.py` to download and prepare the labels with full descriptions
3. Run `python translate_labels.py` to translate the labels
4. If there are any missing translations, run `python fix_missing_translations.py` to fix them
5. Use the resulting `translated_labels.json` (or `translated_labels_fixed.json`) file directly in your application

## Notes

- The scripts now use the official ImageNet class descriptions from the Waikato University reference site: https://deeplearning.cms.waikato.ac.nz/user-guide/class-maps/IMAGENET/
- Full term sets (e.g., "tench, Tinca tinca") are preserved for better context
- The translation focuses on the main concept while preserving the full description
- A two-pass approach ensures all labels get translated
- Always review machine translations before using them in your application 
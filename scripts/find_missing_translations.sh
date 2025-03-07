#!/bin/bash

# Find missing translations in the Tono app
# This script extracts categories from the ML model and checks for missing translations

# Set the paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TRANSLATIONS_PATH="$SCRIPT_DIR/../Tono/Resources/translations.json"
ML_MODEL_PATH="$SCRIPT_DIR/../Tono/Models/Inceptionv3.mlmodel"
CATEGORIES_PATH="/tmp/tono_categories.txt"
OUTPUT_PATH="$SCRIPT_DIR/../missing_translations_template.json"

# Check if translations file exists
if [ ! -f "$TRANSLATIONS_PATH" ]; then
    echo "Error: Translations file not found at $TRANSLATIONS_PATH"
    exit 1
fi

# Check if ML model exists
if [ ! -f "$ML_MODEL_PATH" ]; then
    echo "Error: ML model not found at $ML_MODEL_PATH"
    exit 1
fi

# Extract categories from ML model
echo "Extracting categories from ML model..."
"$SCRIPT_DIR/extract_ml_categories.swift" "$ML_MODEL_PATH" "$CATEGORIES_PATH"

# Check if categories file was created
if [ ! -f "$CATEGORIES_PATH" ]; then
    echo "Error: Failed to extract categories"
    exit 1
fi

# Find missing translations
echo -e "\nChecking for missing translations..."
"$SCRIPT_DIR/check_missing_translations.swift" "$TRANSLATIONS_PATH" "$CATEGORIES_PATH" "$OUTPUT_PATH"

echo -e "\nDone!"
echo "If you want to add the missing translations, edit the file: $OUTPUT_PATH"
echo "Then merge it with your existing translations.json file." 
#!/bin/bash

# Simplified Translation Workflow Script
# This script runs the workflow to extract and translate ImageNet labels

# Check if OpenAI API key is set
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Warning: OPENAI_API_KEY environment variable is not set."
    echo "Please set it with: export OPENAI_API_KEY='your-api-key'"
    echo "Or enter your OpenAI API key now:"
    read -r api_key
    if [ -n "$api_key" ]; then
        export OPENAI_API_KEY="$api_key"
    else
        echo "No API key provided. Exiting."
        exit 1
    fi
fi

# # Install required packages
# echo "Installing required packages..."
# pip install requests beautifulsoup4 openai

# # Step 1: Extract ImageNet labels with full descriptions
# echo -e "\n=== Step 1: Extracting ImageNet labels with full descriptions ==="
# python extract_imagenet_labels.py

# # Check if extraction was successful
# if [ ! -f "imagenet_labels_for_translation.json" ]; then
#     echo "Error: Failed to extract ImageNet labels."
#     exit 1
# fi

# # Step 2: Translate the labels
# echo -e "\n=== Step 2: Translating labels with OpenAI ==="
# # Automatically select OpenAI method (option 1)
# echo "1" | python translate_labels.py

# # Check if translation was successful
# if [ ! -f "translated_labels.json" ]; then
#     echo "Error: Failed to translate labels."
#     exit 1
# fi

# Step 3: Fix any missing translations
echo -e "\n=== Step 3: Fixing any missing translations ==="
python fix_missing_translations.py

# Check if fix was successful
if [ ! -f "translated_labels_fixed.json" ]; then
    echo "Warning: No fixed translations file was created. This could mean there were no missing translations or the fix script failed."
    echo "The translated labels are available in translated_labels.json"
else
    echo "Successfully fixed missing translations."
    echo "The complete translated labels are available in translated_labels_fixed.json"
    # Optionally replace the original file with the fixed one
    cp translated_labels_fixed.json translated_labels.json
    echo "Replaced original translations with fixed version."
fi

echo -e "\n=== Translation workflow complete! ==="
echo "You can now use these translations directly in your application." 
#!/bin/bash

# Install required Python packages
echo "Installing required Python packages..."
pip install requests beautifulsoup4 openai

echo "Dependencies installed successfully!"
echo "You can now run the scripts in the following order:"
echo "1. python extract_imagenet_labels.py"
echo "2. python translate_labels.py"
echo "3. python merge_translations.py" 
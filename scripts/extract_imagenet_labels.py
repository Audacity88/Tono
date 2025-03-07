#!/usr/bin/env python3
import json
import requests
import os
import re
from bs4 import BeautifulSoup

def download_imagenet_labels():
    """Download ImageNet class labels from GitHub."""
    url = "https://raw.githubusercontent.com/anishathalye/imagenet-simple-labels/master/imagenet-simple-labels.json"
    response = requests.get(url)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Failed to download labels: {response.status_code}")
        return []

def fetch_imagenet_categories():
    """Fetch ImageNet categories and their corresponding descriptions from Waikato website."""
    url = "https://deeplearning.cms.waikato.ac.nz/user-guide/class-maps/IMAGENET/"
    try:
        response = requests.get(url)
        if response.status_code != 200:
            print(f"Failed to fetch ImageNet categories: {response.status_code}")
            return {}
        
        # Parse the HTML content
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Find the table with class mappings
        categories = {}
        class_descriptions = {}
        
        # The table has rows with class ID and description
        for row in soup.find_all('tr'):
            cells = row.find_all('td')
            if len(cells) >= 2:
                try:
                    class_id = int(cells[0].text.strip())
                    description = cells[1].text.strip()
                    
                    # Store the full description for each class ID
                    class_descriptions[class_id] = description
                except (ValueError, IndexError):
                    continue
        
        return class_descriptions
    
    except Exception as e:
        print(f"Error fetching ImageNet categories: {e}")
        return {}

def map_labels_to_descriptions(labels, class_descriptions):
    """Map simple labels to their full descriptions from the ImageNet class list."""
    label_to_description = {}
    
    # Create a mapping of lowercase simple labels to their full descriptions
    for class_id, description in class_descriptions.items():
        # Extract the simple label from the description
        # Descriptions often have format like "tench, Tinca tinca"
        simple_parts = description.split(',')[0].lower().split()
        simple_label = simple_parts[0]  # First word as fallback
        
        # Try to match with the downloaded labels
        for label in labels:
            label_lower = label.lower().replace('_', ' ')
            
            # Check if this label is in the description
            if label_lower in description.lower():
                label_to_description[label_lower] = description
                break
            
            # Check if the first word of the label matches
            if label_lower.split()[0] == simple_label:
                label_to_description[label_lower] = description
    
    # For labels without a match, use a direct matching approach
    for label in labels:
        label_lower = label.lower().replace('_', ' ')
        if label_lower not in label_to_description:
            for description in class_descriptions.values():
                if label_lower in description.lower():
                    label_to_description[label_lower] = description
                    break
    
    return label_to_description

def prepare_for_translation(labels, class_descriptions):
    """Prepare labels for translation by formatting them as JSON with full descriptions."""
    translation_entries = []
    
    # Map labels to their full descriptions
    label_to_description = map_labels_to_descriptions(labels, class_descriptions)
    
    for label in labels:
        # Clean up the label
        clean_label = label.lower().replace('_', ' ').strip()
        
        # Get the full description if available
        full_description = label_to_description.get(clean_label, clean_label)
        
        # Determine category based on the description
        if ',' in full_description:
            # Use the first part before the comma as the category
            category = full_description.split(',')[0].strip()
        else:
            category = full_description
        
        # Create entry with the full description as the English term
        entry = {
            "english": full_description,
            "chinese": "",  # To be filled in
            "pinyin": "",   # To be filled in
            "category": category
        }
        
        translation_entries.append(entry)
    
    return translation_entries

def save_to_json(entries, filename="imagenet_labels_for_translation.json"):
    """Save the entries to a JSON file."""
    data = {"objects": entries}
    
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"Saved {len(entries)} labels to {filename}")

def main():
    print("Downloading ImageNet labels...")
    labels = download_imagenet_labels()
    
    if not labels:
        print("No labels downloaded. Exiting.")
        return
    
    print(f"Downloaded {len(labels)} labels.")
    
    print("Fetching ImageNet class descriptions...")
    class_descriptions = fetch_imagenet_categories()
    
    if not class_descriptions:
        print("Warning: Could not fetch class descriptions. Using simple labels only.")
        # Create a simple mapping using just the labels
        class_descriptions = {i: label for i, label in enumerate(labels)}
    else:
        print(f"Fetched {len(class_descriptions)} class descriptions.")
    
    # Prepare for translation
    entries = prepare_for_translation(labels, class_descriptions)
    
    # Save to JSON
    save_to_json(entries)
    
    print("Done! You can now translate the labels and add them to your app's translations.json file.")

if __name__ == "__main__":
    main() 
#!/bin/bash
# Script to install required packages and export YOLOv8 model to CoreML format

# Create a virtual environment (optional)
# python -m venv venv
# source venv/bin/activate

# Install required packages
echo "Installing required packages..."
pip install ultralytics

# Create Models directory if it doesn't exist
mkdir -p Models

# Run the export script
echo "Running export script..."
python export_yolov8_coreml.py

# If the first script fails, try the CLI version
if [ $? -ne 0 ]; then
    echo "First export script failed, trying CLI version..."
    python export_yolov8_cli.py
fi

# Check if the model was exported successfully
if [ -d "Models/yolov8n_nms.mlpackage" ]; then
    echo "Model exported successfully to Models/yolov8n_nms.mlpackage"
    echo "Add this model to your Xcode project to use it in your app."
else
    echo "Model export failed. Check the logs for details."
fi 
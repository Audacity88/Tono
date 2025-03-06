#!/usr/bin/env python3
"""
Export YOLOv8 model to CoreML format with NMS enabled.
This script downloads the YOLOv8n model and exports it to CoreML format
with Non-Maximum Suppression (NMS) enabled, which is required for proper
object detection in iOS apps.
"""

import os
from ultralytics import YOLO

def export_yolov8_to_coreml(model_size='n', output_dir='./'):
    """
    Export YOLOv8 model to CoreML format with NMS enabled.
    
    Args:
        model_size (str): Size of the YOLOv8 model ('n', 's', 'm', 'l', 'x')
        output_dir (str): Directory to save the exported model
    
    Returns:
        str: Path to the exported model
    """
    print(f"Exporting YOLOv8{model_size} to CoreML format with NMS enabled...")
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Load the model
    model_name = f"yolov8{model_size}"
    model = YOLO(f"{model_name}.pt")
    
    # Export to CoreML with NMS enabled
    # Note: The export function will save the model to the default path: 'runs/detect/export'
    # We'll need to move it to our desired location after export
    model.export(format='coreml', nms=True, imgsz=640)
    
    # Default export path
    default_export_path = os.path.join('runs', 'detect', 'export', f"{model_name}.mlpackage")
    
    # Target path
    target_path = os.path.join(output_dir, f"{model_name}_nms.mlpackage")
    
    # Check if the exported model exists
    if os.path.exists(default_export_path):
        # Create the target directory if it doesn't exist
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        
        # Move the exported model to the target path
        import shutil
        if os.path.exists(target_path):
            shutil.rmtree(target_path)
        shutil.move(default_export_path, target_path)
        print(f"Model exported and moved to {target_path}")
    else:
        print(f"Warning: Exported model not found at {default_export_path}")
        print("Check the Ultralytics export logs for details.")
    
    return target_path

if __name__ == "__main__":
    # Export YOLOv8n model
    export_yolov8_to_coreml(model_size='n', output_dir='./Models') 
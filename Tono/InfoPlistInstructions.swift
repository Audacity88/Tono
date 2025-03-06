// InfoPlistInstructions.swift
// Tono
//
// This file contains instructions for adding necessary permissions to Info.plist in Xcode

/*
 To add the required permissions for Tono in Xcode:
 
 1. Open your Tono project in Xcode
 2. Select the Tono project in the Project Navigator (left sidebar)
 3. Select the "Tono" target under TARGETS
 4. Go to the "Info" tab
 5. Add the following permission keys by hovering over any existing item, clicking the "+" button, and adding each key:
 
    - Camera Usage Description:
      - Key: NSCameraUsageDescription
      - Value: "Tono needs camera access to recognize objects for Chinese learning"
 
    - Microphone Usage Description:
      - Key: NSMicrophoneUsageDescription
      - Value: "Tono needs microphone access to record your pronunciation"
 
    - Speech Recognition Usage Description:
      - Key: NSSpeechRecognitionUsageDescription
      - Value: "Tono needs speech recognition to assess your pronunciation"
 
 6. Save your changes
 
 Additionally, add the required capabilities:
 
 1. While still in the Tono target settings, go to the "Signing & Capabilities" tab
 2. Click the "+ Capability" button
 3. Search for and add:
    - ARKit (for augmented reality)
    - Speech Recognition (for speech processing)
 */

import Foundation

// This is just a placeholder file with instructions
// No actual code is needed here 